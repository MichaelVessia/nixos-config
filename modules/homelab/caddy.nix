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
    "tubearchivist" = "tubearchivist";
    "signoz" = "signoz";
    "paperless" = "paperless";
  };
  proxyConfig = upstream: "reverse_proxy ${upstream}";
  proxy = upstream: {extraConfig = proxyConfig upstream;};
  mapleUpstream = "127.0.0.1:${toString services.maple.port}";
  mapleMetricsSources = cfg.topology.network.otlpAllowlist ++ ["100.64.0.0/10"];
  maplePublicProxy = ''
    @host_metrics {
      method POST
      path /v1/metrics
      remote_ip ${lib.concatStringsSep " " mapleMetricsSources}
    }
    handle @host_metrics {
      reverse_proxy ${mapleUpstream} {
        header_up x-maple-ingest-key {env.MAPLE_LOCAL_INGEST_KEY}
      }
    }
    handle {
      ${proxyConfig mapleUpstream}
    }
  '';
  proxyWithSelfSignedTlsConfig = upstream: ''
    reverse_proxy ${upstream} {
      transport http {
        dial_timeout 15s
        tls_insecure_skip_verify
      }
    }
  '';
  proxyWithSelfSignedTls = upstream: {extraConfig = proxyWithSelfSignedTlsConfig upstream;};
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
  publicWildcardHandlers = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      label: service:
        wildcardHandle label [label] (proxyConfig "${cfg.hostIp}:${toString services.${service}.port}")
    )
    appServices
    ++ [
      (wildcardHandle "maple" ["maple"] maplePublicProxy)
      (wildcardHandle "adguard" ["adguard"] (proxyConfig "127.0.0.1:${toString services.adguard.port}"))
      (wildcardHandle "caddy" ["caddy"] ''
        respond / "Caddy is running." 200
        respond 404
      '')
      (wildcardHandle "unifi" ["unifi"] (proxyWithSelfSignedTlsConfig "https://192.168.1.1"))
      (wildcardHandle "synology" ["synology" "nas"] (proxyWithSelfSignedTlsConfig "https://${cfg.topology.nas.ip}:5001"))
      (wildcardHandle "calibre" ["calibre"] (proxyConfig "${cfg.topology.nas.ip}:8080"))
      (wildcardHandle "brother" ["brother"] (proxyConfig "192.168.1.28"))
      (wildcardHandle "syncthing" ["syncthing"] (proxyConfig caddyCfg.syncthingUpstream))
      (wildcardHandle "homeassistant" ["homeassistant" "ha"] homeAssistantProxyConfig)
    ]
    ++ lib.optionals (caddyCfg.executorUpstream != null) [
      (wildcardHandle "executor" ["executor"] (proxyConfig caddyCfg.executorUpstream))
    ]
    ++ lib.optionals (caddyCfg.haMcpUpstream != null) [
      (wildcardHandle "ha_mcp" ["ha-mcp"] (proxyConfig caddyCfg.haMcpUpstream))
    ]
  );
in {
  options.homelab.caddy = {
    enable = lib.mkEnableOption "homelab reverse proxy (Caddy)";

    publicDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional public base domain (e.g. home.vessia.net) served with a Let's Encrypt Cloudflare DNS-01 wildcard certificate alongside *.lan.";
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

    systemd.services.caddy = lib.mkIf (caddyCfg.legacyAliases != [] || hasPublicDomain) {
      after =
        lib.optionals (caddyCfg.legacyAliases != []) ["homelab-legacy-ips.service"]
        ++ lib.optionals hasPublicDomain ["acme-${publicDomain}.service"];
      wants =
        lib.optionals (caddyCfg.legacyAliases != []) ["homelab-legacy-ips.service"]
        ++ lib.optionals hasPublicDomain ["acme-${publicDomain}.service"];
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
        lib.mapAttrs' (label: service: lib.nameValuePair "${label}.lan" (proxy "${cfg.hostIp}:${toString services.${service}.port}")) appServices
        // {
          "maple.lan" = proxy mapleUpstream;
          "adguard.lan" = proxy "127.0.0.1:${toString services.adguard.port}";
          "caddy.lan".extraConfig = ''
            respond / "Caddy is running." 200
            respond 404
          '';

          "unifi.lan" = proxyWithSelfSignedTls "https://192.168.1.1";
          "synology.lan" =
            proxyWithSelfSignedTls "https://${cfg.topology.nas.ip}:5001"
            // {serverAliases = ["nas.lan"];};
          "calibre.lan" = proxy "${cfg.topology.nas.ip}:8080";
          "brother.lan" = proxy "192.168.1.28";

          "proxmox.lan" = lib.mkIf (caddyCfg.proxmoxUpstream != null) (proxyWithSelfSignedTls caddyCfg.proxmoxUpstream);
          "syncthing.lan" = proxy caddyCfg.syncthingUpstream;
          "homeassistant.lan" = {
            serverAliases = ["ha.lan"];
            extraConfig = homeAssistantProxyConfig;
          };
          "executor.lan" = lib.mkIf (caddyCfg.executorUpstream != null) (proxy caddyCfg.executorUpstream);
          "ha-mcp.lan" = lib.mkIf (caddyCfg.haMcpUpstream != null) (proxy caddyCfg.haMcpUpstream);
        }
        // lib.optionalAttrs hasPublicDomain {
          "${publicDomain}".extraConfig = ''
            ${acmeTls}
            ${proxyConfig "${cfg.hostIp}:${toString services.homepage.port}"}
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
