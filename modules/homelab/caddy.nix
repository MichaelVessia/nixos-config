{
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
  caddyCfg = cfg.caddy;
  services = cfg.topology.services;
  appServices = {
    "homepage.lan" = "homepage";
    "uptimekuma.lan" = "uptimekuma";
    "lazylibrarian.lan" = "lazylibrarian";
    "autocaliweb.lan" = "autocaliweb";
    "freshrss.lan" = "freshrss";
    "jellyseerr.lan" = "seerr";
    "jellyfin.lan" = "jellyfin";
    "radarr.lan" = "radarr";
    "sonarr.lan" = "sonarr";
    "prowlarr.lan" = "prowlarr";
    "sabnzbd.lan" = "sabnzbd";
    "immich.lan" = "immich";
    "kiosk.lan" = "kiosk";
    "tubearchivist.lan" = "tubearchivist";
    "signoz.lan" = "signoz";
  };
  proxy = upstream: {extraConfig = "reverse_proxy ${upstream}";};
  proxyWithSelfSignedTls = upstream: {
    extraConfig = ''
      reverse_proxy ${upstream} {
        transport http {
          tls_insecure_skip_verify
        }
      }
    '';
  };
in {
  options.homelab.caddy = {
    enable = lib.mkEnableOption "homelab reverse proxy (Caddy)";

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
  };

  config = lib.mkIf (cfg.enable && caddyCfg.enable) {
    services.caddy = {
      enable = true;
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
        lib.mapAttrs (_: service: proxy "${cfg.hostIp}:${toString services.${service}.port}") appServices
        // {
          "adguard.lan" = proxy "127.0.0.1:${toString services.adguard.port}";
          "caddy.lan".extraConfig = ''
            respond / "Caddy is running." 200
            respond 404
          '';

          "unifi.lan" = proxyWithSelfSignedTls "https://192.168.1.1";
          "synology.lan" =
            proxyWithSelfSignedTls "https://${cfg.topology.nas.ip}:5001"
            // {serverAliases = ["nas.lan"];};
          "paperless.lan" = proxy "${cfg.topology.nas.ip}:8000";
          "calibre.lan" = proxy "${cfg.topology.nas.ip}:8080";
          "brother.lan" = proxy "192.168.1.28";

          "proxmox.lan" = lib.mkIf (caddyCfg.proxmoxUpstream != null) (proxyWithSelfSignedTls caddyCfg.proxmoxUpstream);
          "syncthing.lan" = proxy caddyCfg.syncthingUpstream;
          "homeassistant.lan" = {
            serverAliases = ["ha.lan"];
            extraConfig = ''
              reverse_proxy ${caddyCfg.homeAssistantUpstream} {
                header_up -X-Forwarded-For
                header_up -X-Forwarded-Proto
                header_up -X-Forwarded-Host
                header_up Host {upstream_hostport}
                header_up X-Forwarded-For {remote_host}
                header_up X-Forwarded-Proto https
              }
            '';
          };
          "executor.lan" = lib.mkIf (caddyCfg.executorUpstream != null) (proxy caddyCfg.executorUpstream);
          "ha-mcp.lan" = lib.mkIf (caddyCfg.haMcpUpstream != null) (proxy caddyCfg.haMcpUpstream);
        };
    };

    networking.firewall.allowedTCPPorts = [
      services.caddy.port
      services.caddy.httpsPort
    ];

    homelab.backups.paths = ["/var/lib/caddy"];
  };
}
