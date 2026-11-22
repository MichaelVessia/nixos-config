{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  appsCfg = cfg.apps;
  caddyServices = [
    "homepage"
    "uptimekuma"
    "sabnzbd"
    "prowlarr"
    "sonarr"
    "radarr"
    "seerr"
    "lazylibrarian"
    "autocaliweb"
    "freshrss"
    "tubearchivist"
  ];
  caddyRule = service: "-s ${lib.escapeShellArg appsCfg.allowExternalCaddyIp} -p tcp --dport ${toString cfg.topology.services.${service}.port} -j nixos-fw-accept";
in {
  options.homelab.apps = {
    enable = lib.mkEnableOption "homelab Docker app host preparation (M2+)";

    allowExternalCaddyIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "192.168.1.252";
      description = "Legacy Caddy CT 115 IP permitted to reach M2 through M4 app ports before M6 moves Caddy onto this host. Set to null once Caddy runs locally.";
    };
  };

  config = lib.mkIf (cfg.enable && appsCfg.enable) {
    systemd.tmpfiles.rules = [
      "d /opt/homelab 0755 root root -"
      "d /opt/homelab/ca 0755 root root -"
      "d /opt/homelab/uptimekuma 0755 root root -"
      "d /opt/homelab/uptimekuma/data 0755 root root -"
      "d /opt/homelab/homepage 0755 root root -"
      "d /opt/homelab/homepage/config 0755 root root -"
      "d /opt/homelab/homepage/icons 0755 root root -"
      "d /opt/homelab/homepage/env 0750 root root -"
      "d /opt/homelab/sabnzbd 0755 root root -"
      "d /opt/homelab/sabnzbd/config - - - -"
      "d /opt/homelab/prowlarr 0755 root root -"
      "d /opt/homelab/prowlarr/config - - - -"
      "d /opt/homelab/sonarr 0755 root root -"
      "d /opt/homelab/sonarr/config - - - -"
      "d /opt/homelab/radarr 0755 root root -"
      "d /opt/homelab/radarr/config - - - -"
      "d /opt/homelab/seerr 0755 root root -"
      "d /opt/homelab/seerr/config - - - -"
      "d /opt/homelab/lazylibrarian 0755 root root -"
      "d /opt/homelab/lazylibrarian/config - - - -"
      "d /opt/homelab/autocaliweb 0755 root root -"
      "d /opt/homelab/autocaliweb/config - - - -"
      "d /opt/homelab/freshrss 0755 root root -"
      "d /opt/homelab/freshrss/data - - - -"
      "d /opt/homelab/freshrss/extensions - - - -"
      "d /opt/homelab/freshrss/postgres - - - -"
      "d /opt/homelab/freshrss/env 0750 root root -"
      "d /opt/homelab/tubearchivist 0755 root root -"
      "d /opt/homelab/tubearchivist/cache - - - -"
      "d /opt/homelab/tubearchivist/es - - - -"
      "d /opt/homelab/tubearchivist/redis - - - -"
      "d /opt/homelab/tubearchivist/env 0750 root root -"
      "d /opt/homelab/jellyfin 0755 root root -"
      "d /opt/homelab/jellyfin/data - - - -"
      "d /opt/homelab/jellyfin/etc - - - -"
      "d /var/cache/homelab 0755 root root -"
      "d /var/cache/homelab/jellyfin - - - -"
    ];

    system.activationScripts.homelabCa = ''
      ${pkgs.coreutils}/bin/install -Dm644 ${../homelab-ca/caddy-local-root.crt} /opt/homelab/ca/caddy-local-root.crt
    '';

    homelab.backups.paths = ["/opt/homelab"];

    networking.firewall = {
      allowedTCPPorts = [cfg.topology.services.jellyfin.port];
      extraCommands = lib.mkIf (appsCfg.allowExternalCaddyIp != null) (
        lib.concatMapStrings (service: ''
          iptables -A nixos-fw ${caddyRule service}
        '')
        caddyServices
      );
      extraStopCommands = lib.mkIf (appsCfg.allowExternalCaddyIp != null) (
        lib.concatMapStrings (service: ''
          iptables -D nixos-fw ${caddyRule service} || true
        '')
        caddyServices
      );
    };
  };
}
