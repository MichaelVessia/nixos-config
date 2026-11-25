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
    "autocaliweb" = "autocaliweb";
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
    "tubearchivist" = "tubearchivist";
    "paperless" = "paperless";
  };
  proxyConfig = upstream: "reverse_proxy ${upstream}";
  mapleUpstream = "127.0.0.1:${toString services.maple.port}";
  mapleSources = cfg.topology.network.otlpAllowlist ++ cfg.topology.network.mapleExtraOtlpSources ++ ["100.64.0.0/10"];
  mapleOtlpPaths = "/v1/metrics /v1/logs /v1/traces";
  mapleProxy = ''
    @allowed_otlp {
      method POST
      path ${mapleOtlpPaths}
      remote_ip ${lib.concatStringsSep " " mapleSources}
    }
    handle @allowed_otlp {
      reverse_proxy ${mapleUpstream} {
        header_up x-maple-ingest-key {env.MAPLE_LOCAL_INGEST_KEY}
      }
    }
    @otlp path ${mapleOtlpPaths}
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
  proxyRoutes =
    lib.mapAttrs' (
      label: service:
        lib.nameValuePair service (tracedRoute [label] (proxyConfig "${cfg.hostIp}:${toString services.${service}.port}"))
    )
    appServices
    // {
      maple = {
        labels = ["maple"];
        extraConfig = mapleProxy;
      };
      adguard = tracedRoute ["adguard"] (proxyConfig "127.0.0.1:${toString services.adguard.port}");
      pocket-id = tracedRoute ["auth"] (proxyConfig "127.0.0.1:${toString services.pocketId.port}");
      tinyauth = tracedRoute ["login"] ''respond 503'';
      unifi = tracedRoute ["unifi"] (proxyWithSelfSignedTlsConfig "https://192.168.1.1");
      synology = tracedRoute ["synology" "nas"] (proxyWithSelfSignedTlsConfig "https://${cfg.topology.nas.ip}:5001");
      calibre = tracedRoute ["calibre"] (proxyConfig "${cfg.topology.nas.ip}:8080");
      brother = tracedRoute ["brother"] (proxyConfig "192.168.1.28");
      syncthing = tracedRoute ["syncthing"] (proxyConfig caddyCfg.syncthingUpstream);
      homeassistant = tracedRoute ["homeassistant" "ha"] homeAssistantProxyConfig;
    }
    // lib.optionalAttrs (caddyCfg.executorUpstream != null) {
      executor = tracedRoute ["executor"] (proxyConfig caddyCfg.executorUpstream);
    }
    // lib.optionalAttrs (caddyCfg.haMcpUpstream != null) {
      "ha-mcp" = tracedRoute ["ha-mcp"] (proxyConfig caddyCfg.haMcpUpstream);
    };
  lanProxyRoutes =
    proxyRoutes
    // lib.optionalAttrs (caddyCfg.proxmoxUpstream != null) {
      proxmox = tracedRoute ["proxmox"] (proxyWithSelfSignedTlsConfig caddyCfg.proxmoxUpstream);
    };
  publicWildcardHandlers = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      service: route: wildcardHandle service route.labels route.extraConfig
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

    proxmoxUpstream = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "https://192.168.1.200:8006";
      description = "Proxmox web interface upstream. Set to null to disable the virtual host.";
    };

    syncthingUpstream = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.22:8384";
      description = "Syncthing web interface upstream.";
    };

    homeAssistantUpstream = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.227:8123";
      description = "Home Assistant web interface upstream.";
    };

    executorUpstream = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.hostIp}:${toString services.executor.port}";
      description = "Executor upstream. Set to null to disable the virtual host.";
    };

    haMcpUpstream = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${cfg.hostIp}:${toString services.haMcp.port}";
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
            ${traced (proxyConfig "${cfg.hostIp}:${toString services.homepage.port}")}
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
