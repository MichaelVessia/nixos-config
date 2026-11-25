{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  caddyCfg = cfg.caddy;
  services = cfg.topology.services;
  publicDomain = caddyCfg.publicDomain;
  hasPublicDomain = publicDomain != null;
  nasRedirectTarget = "https://nas.${publicDomain}{uri}";
  traceEnabled = caddyCfg.traceEndpoint != null;
  acmeDir =
    if hasPublicDomain
    then config.security.acme.certs.${publicDomain}.directory
    else "";
  acmeTls = "tls ${acmeDir}/fullchain.pem ${acmeDir}/key.pem";
  legacyAliasIps = lib.unique (map (alias: alias.ip) caddyCfg.legacyAliases);
  legacyAliasNatRules =
    lib.concatMap (alias: [
      "PREROUTING -d ${lib.escapeShellArg alias.ip} -p tcp --dport ${toString alias.port} -j DNAT --to-destination ${lib.escapeShellArg alias.upstream}"
      "OUTPUT -d ${lib.escapeShellArg alias.ip} -p tcp --dport ${toString alias.port} -j DNAT --to-destination ${lib.escapeShellArg alias.upstream}"
    ])
    caddyCfg.legacyAliases;
  appServices = {
    "homepage" = "homepage";
    "uptimekuma" = "uptimekuma";
    "lazylibrarian" = "lazylibrarian";
    "chaptarr" = "chaptarr";
    "freshrss" = "freshrss";
    "jellyseerr" = "seerr";
    "jellyfin" = "jellyfin";
    "radarr" = "radarr";
    "sonarr" = "sonarr";
    "prowlarr" = "prowlarr";
    "sabnzbd" = "sabnzbd";
    "immich" = "immich";
    "kiosk" = "kiosk";
    "frame" = "frame";
    "paperless" = "paperless";
    "teddycloud" = "teddycloud";
  };
  arrClientPaths = ["/api" "/api/*" "/ping" "/feed" "/feed/*"];
  mapleOtlpPaths = ["/v1/metrics" "/v1/logs" "/v1/traces"];
  adminClientPaths = {
    adguard = ["/control/*"];
    autocaliweb = ["/health" "/opds" "/opds/*"];
    brother = [];
    calibre = [];
    chaptarr = arrClientPaths;
    freshrss = ["/api/*"];
    lazylibrarian = ["/api"];
    maple = ["/health" "/local/status" "/local/query"] ++ mapleOtlpPaths;
    musicAssistant = ["/health"];
    prowlarr = arrClientPaths;
    radarr = arrClientPaths;
    sabnzbd = arrClientPaths;
    sonarr = arrClientPaths;
    syncthing = ["/rest/*"];
    teddycloud = ["/health"];
    tubearchivist = [];
    uptimekuma = ["/api/push/*" "/api/status-page/*" "/status" "/status/*" "/metrics"];
  };
  tubeApiToken = "path('/api/*') && header_regexp('Authorization', '(?i)^Token[ ]+')";
  tubeApiClient = "path('/api/health/') || (${tubeApiToken}) || (path('/api/*') && method('OPTIONS'))";
  adminUiMatcher = service: let
    paths = adminClientPaths.${service};
  in
    if service == "tubearchivist"
    then "@adminUi expression !(${tubeApiClient})"
    else if paths == []
    then "@adminUi expression true"
    else "@adminUi not path ${lib.concatStringsSep " " paths}";
  stripAuthHeaders = ''
    request_header -Remote-User
    request_header -Remote_User
    request_header -Remote-Name
    request_header -Remote-Email
    request_header -Remote-Groups
    request_header -X-WebAuth-User
  '';
  tinyauthForwardAuth = service: body: ''
    ${adminUiMatcher service}
    route {
      ${stripAuthHeaders}
      forward_auth @adminUi 127.0.0.1:${toString services.tinyauth.port} {
        uri /api/auth/caddy
        copy_headers Remote-User Remote-Name Remote-Email Remote-Groups
      }
      ${body}
    }
  '';
  proxyConfig = upstream: "reverse_proxy ${upstream}";
  appUpstream = service: let
    address =
      if service.bind == "loopback"
      then "127.0.0.1"
      else cfg.hostIp;
  in "${address}:${toString service.port}";
  mapleUpstream = "127.0.0.1:${toString services.maple.port}";
  mapleSources = cfg.topology.network.otlpAllowlist ++ cfg.topology.network.mapleExtraOtlpSources ++ ["100.64.0.0/10"];
  mapleOtlpPathMatcher = "path ${lib.concatStringsSep " " mapleOtlpPaths}";
  mapleProxy = ''
    @allowed_otlp {
      method POST
      ${mapleOtlpPathMatcher}
      remote_ip ${lib.concatStringsSep " " mapleSources}
    }
    handle @allowed_otlp {
      reverse_proxy ${mapleUpstream} {
        header_up x-maple-ingest-key {env.MAPLE_LOCAL_INGEST_KEY}
      }
    }
    @otlp ${mapleOtlpPathMatcher}
    handle @otlp {
      respond 403
    }
    handle {
      ${traced (proxyConfig mapleUpstream)}
    }
  '';
  traced = body: ''
    ${lib.optionalString traceEnabled ''
      @traceable not path_regexp ^/(?:[^/]+/)*(?:health|healthz|ready|readyz|healthcheck)(?:/.*)?$
      tracing @traceable {
        span "{http.request.method} {http.request.host}"
      }
    ''}
    ${body}
  '';
  proxyWithSelfSignedTlsConfig = upstream: ''
    reverse_proxy ${upstream} {
      transport http {
        dial_timeout 15s
        tls_insecure_skip_verify
      }
    }
  '';
  homeAssistantProxyConfig = ''
    reverse_proxy ${caddyCfg.homeAssistantUpstream} {
      header_up -X-Forwarded-For
      header_up -X-Forwarded-Proto
      header_up -X-Forwarded-Host
      header_up Host {upstream_hostport}
      header_up X-Forwarded-For {remote_host}
      header_up X-Forwarded-Proto https
    }
  '';
  wildcardHandle = name: hosts: body: ''
    @${name} host ${lib.concatStringsSep " " (map (h: "${h}.${publicDomain}") hosts)}
    handle @${name} {
      ${body}
    }
  '';
  tracedRoute = labels: body: {
    inherit labels;
    extraConfig = traced body;
  };
  autoCaliWebProxy = ''
    # Keep the existing OPDS username for Basic auth clients.
    @pocketIdMichael header Remote-User michaelvessia
    request_header @pocketIdMichael Remote-User michael
    ${proxyConfig (appUpstream services.autocaliweb)}
  '';
  tubeArchivistProxy = ''
    # Token requests must use their API token, even if they carry a session cookie.
    @tubeApiToken expression ${tubeApiToken}
    request_header @tubeApiToken -Cookie
    ${proxyConfig (appUpstream services.tubearchivist)}
  '';
  teddycloudProxy = ''
    handle /health {
      reverse_proxy ${appUpstream services.teddycloud} {
        method GET
        rewrite /web/
        @ready status 200
        handle_response @ready {
          respond 204
        }
      }
    }
    handle {
      ${proxyConfig (appUpstream services.teddycloud)}
    }
  '';
  proxyRoutes =
    lib.mapAttrs' (
      label: service:
        lib.nameValuePair service (tracedRoute [label] (
          if service == "teddycloud"
          then teddycloudProxy
          else proxyConfig (appUpstream services.${service})
        ))
    )
    appServices
    // {
      autocaliweb = tracedRoute ["autocaliweb"] autoCaliWebProxy;
      maple = {
        labels = ["maple"];
        extraConfig = mapleProxy;
      };
      musicAssistant = tracedRoute ["music"] ''
        handle /health {
          reverse_proxy ${appUpstream services.musicAssistant} {
            method GET
            rewrite /info
            @ready status 200
            handle_response @ready {
              respond 204
            }
          }
        }
        handle {
          ${proxyConfig (appUpstream services.musicAssistant)}
        }
      '';
      adguard = tracedRoute ["adguard"] (proxyConfig "127.0.0.1:${toString services.adguard.port}");
      pocket-id = tracedRoute ["auth"] (proxyConfig "127.0.0.1:${toString services.pocketId.port}");
      tinyauth = tracedRoute ["login"] (proxyConfig "127.0.0.1:${toString services.tinyauth.port}");
      unifi = tracedRoute ["unifi"] (proxyWithSelfSignedTlsConfig "https://192.168.1.1");
      synology = tracedRoute ["synology" "nas"] (proxyWithSelfSignedTlsConfig "https://${cfg.topology.nas.ip}:5001");
      calibre = tracedRoute ["calibre"] (proxyConfig "${cfg.topology.nas.ip}:8080");
      brother = tracedRoute ["brother"] (proxyConfig "192.168.1.28");
      syncthing = tracedRoute ["syncthing"] (proxyConfig caddyCfg.syncthingUpstream);
      tubearchivist = tracedRoute ["tubearchivist"] tubeArchivistProxy;
      homeassistant = tracedRoute ["homeassistant" "ha"] homeAssistantProxyConfig;
    }
    // lib.optionalAttrs (caddyCfg.executorUpstream != null) {
      executor = tracedRoute ["executor"] (proxyConfig caddyCfg.executorUpstream);
    }
    // lib.optionalAttrs (caddyCfg.haMcpUpstream != null) {
      "ha-mcp" = tracedRoute ["ha-mcp"] (proxyConfig caddyCfg.haMcpUpstream);
    };
  lanProxyRoutes =
    lib.mapAttrs (
      service: route:
        if hasPublicDomain && adminClientPaths ? ${service}
        then
          route
          // {
            extraConfig = ''
              ${adminUiMatcher service}
              redir @adminUi https://${builtins.head route.labels}.${publicDomain}{uri} 308
              route {
                ${stripAuthHeaders}
                ${route.extraConfig}
              }
            '';
          }
        else if hasPublicDomain && service == "tinyauth"
        then route // {extraConfig = "redir https://login.${publicDomain}{uri} 308";}
        else if hasPublicDomain && service == "synology"
        then route // {extraConfig = "redir ${nasRedirectTarget} 308";}
        else route
    )
    proxyRoutes;
  publicWildcardHandlers = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      service: route:
        wildcardHandle service route.labels (
          if adminClientPaths ? ${service}
          then tinyauthForwardAuth service route.extraConfig
          else if service == "synology"
          then ''
            @synologyAlias host synology.${publicDomain}
            redir @synologyAlias ${nasRedirectTarget} 308
            ${route.extraConfig}
          ''
          else route.extraConfig
        )
    )
    proxyRoutes
    ++ [
      (wildcardHandle "caddy" ["caddy"] ''
        respond / "Caddy is running." 200
        respond 404
      '')
    ]
  );
  routeHosts = domain: routes:
    lib.concatLists (lib.mapAttrsToList (
        service: route: map (label: lib.nameValuePair "${label}.${domain}" service) route.labels
      )
      routes);
in {
  options.homelab.caddy = {
    enable = lib.mkEnableOption "homelab reverse proxy (Caddy)";

    publicDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional public base domain (e.g. home.vessia.net) served with a Let's Encrypt Cloudflare DNS-01 wildcard certificate alongside *.lan.";
    };

    traceEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "OTLP HTTP endpoint for Caddy traces, including the /v1/traces path.";
    };

    traceServices = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      internal = true;
      description = "Canonical service names by proxy hostname.";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      default = "michael@vessia.net";
      description = "Contact email for ACME / Let's Encrypt certificate registration.";
    };

    syncthingUpstream = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:${toString cfg.topology.services.syncthing.uiPort}";
      description = "Syncthing web interface upstream.";
    };

    homeAssistantUpstream = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.227:8123";
      description = "Home Assistant web interface upstream.";
    };

    executorUpstream = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = appUpstream services.executor;
      description = "Executor upstream. Set to null to disable the virtual host.";
    };

    haMcpUpstream = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = appUpstream services.haMcp;
      description = "Home Assistant MCP upstream. Set to null to disable the virtual host.";
    };

    aliasInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Ethernet interface that hosts secondary legacyAliases IPv4 addresses (e.g. enp5s0 on forge).";
    };

    legacyAliases = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          ip = lib.mkOption {
            type = lib.types.str;
            description = "Secondary IPv4 address to bind on aliasInterface.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "Plain HTTP listen port on the secondary IP.";
          };
          upstream = lib.mkOption {
            type = lib.types.str;
            description = "Upstream host:port forwarded by Caddy.";
          };
        };
      });
      default = [];
      description = "Legacy Proxmox IP:port aliases kept alive over plain HTTP for hardcoded LAN clients such as TVs.";
    };
  };

  config = lib.mkIf (cfg.enable && caddyCfg.enable) {
    homelab.caddy.traceServices = builtins.listToAttrs (
      routeHosts "lan" lanProxyRoutes
      ++ lib.optionals hasPublicDomain (
        routeHosts publicDomain proxyRoutes ++ [(lib.nameValuePair publicDomain "homepage")]
      )
    );

    assertions = [
      {
        assertion = caddyCfg.legacyAliases == [] || caddyCfg.aliasInterface != null;
        message = "homelab.caddy.aliasInterface must be set when homelab.caddy.legacyAliases is non-empty.";
      }
    ];

    sops.secrets = lib.mkIf hasPublicDomain {
      homelab_maple_env.restartUnits = ["caddy.service"];
      homelab_cloudflare_dns_env = {
        sopsFile = cfg.backups.sopsFile;
        owner = "root";
        mode = "0400";
      };
    };

    security.acme = lib.mkIf hasPublicDomain {
      acceptTerms = true;
      defaults.email = caddyCfg.acmeEmail;
      certs.${publicDomain} = {
        domain = publicDomain;
        extraDomainNames = ["*.${publicDomain}"];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        environmentFile = config.sops.secrets.homelab_cloudflare_dns_env.path;
        group = config.services.caddy.group;
        reloadServices = ["caddy.service"];
      };
    };

    systemd.services.homelab-legacy-ips = lib.mkIf (caddyCfg.legacyAliases != []) {
      description = "Configure legacy homelab secondary IPv4 aliases";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      before = ["caddy.service"];
      wantedBy = ["multi-user.target" "caddy.service"];
      path = [pkgs.iproute2];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script =
        lib.concatMapStrings (ip: ''
          ip addr replace ${lib.escapeShellArg "${ip}/24"} dev ${lib.escapeShellArg caddyCfg.aliasInterface}
        '')
        legacyAliasIps;
      preStop =
        lib.concatMapStrings (ip: ''
          ip addr del ${lib.escapeShellArg "${ip}/24"} dev ${lib.escapeShellArg caddyCfg.aliasInterface} 2>/dev/null || true
        '')
        legacyAliasIps;
    };

    systemd.services.caddy = {
      after =
        lib.optionals (caddyCfg.legacyAliases != []) ["homelab-legacy-ips.service"]
        ++ lib.optionals hasPublicDomain ["acme-${publicDomain}.service"];
      wants =
        lib.optionals (caddyCfg.legacyAliases != []) ["homelab-legacy-ips.service"]
        ++ lib.optionals hasPublicDomain ["acme-${publicDomain}.service"];
      environment = lib.mkIf traceEnabled {
        OTEL_SERVICE_NAME = "caddy";
        OTEL_RESOURCE_ATTRIBUTES = "host.name=${config.networking.hostName}";
        OTEL_EXPORTER_OTLP_TRACES_PROTOCOL = "http/protobuf";
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = caddyCfg.traceEndpoint;
      };
    };

    services.caddy = {
      enable = true;
      environmentFile = lib.mkIf hasPublicDomain config.sops.secrets.homelab_maple_env.path;
      globalConfig = ''
        admin 127.0.0.1:${toString services.caddy.adminPort}
        default_bind ${cfg.hostIp}
        local_certs
        skip_install_trust
      '';
      # Declare the HTTP listener so automatic HTTPS redirects use default_bind.
      extraConfig = ''
        http:// {
        }
      '';

      virtualHosts =
        lib.mapAttrs' (
          _: route:
            lib.nameValuePair "${builtins.head route.labels}.lan" {
              serverAliases = map (label: "${label}.lan") (builtins.tail route.labels);
              inherit (route) extraConfig;
            }
        )
        lanProxyRoutes
        // {
          "caddy.lan".extraConfig = ''
            respond / "Caddy is running." 200
            respond 404
          '';
        }
        // lib.optionalAttrs hasPublicDomain {
          "${publicDomain}".extraConfig = ''
            ${acmeTls}
            ${traced (proxyConfig (appUpstream services.homepage))}
          '';
          "*.${publicDomain}".extraConfig = ''
            ${acmeTls}
            ${publicWildcardHandlers}
            handle {
              respond 404
            }
          '';
        };
    };

    networking.firewall = {
      allowedTCPPorts = [
        services.caddy.port
        services.caddy.httpsPort
      ];
      extraCommands = lib.mkIf (legacyAliasNatRules != []) (
        lib.concatMapStrings (rule: ''
          iptables -t nat -I ${rule}
        '')
        legacyAliasNatRules
      );
      extraStopCommands = lib.mkIf (legacyAliasNatRules != []) (
        lib.concatMapStrings (rule: ''
          iptables -t nat -D ${rule} || true
        '')
        legacyAliasNatRules
      );
    };

    homelab.backups.paths = ["/var/lib/caddy"];
  };
}
