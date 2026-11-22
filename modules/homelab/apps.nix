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
    "immich"
    "signoz"
  ];
  caddyRule = service: "-s ${lib.escapeShellArg appsCfg.allowExternalCaddyIp} -p tcp --dport ${toString cfg.topology.services.${service}.port} -j nixos-fw-accept";
  otlpPort = toString cfg.topology.services.signoz.otlpGrpcPort;
  otlpSources = cfg.topology.network.otlpAllowlist ++ ["100.64.0.0/10"];
  otlpRule = source: "-s ${lib.escapeShellArg source} -p tcp --dport ${otlpPort} -j nixos-fw-accept";
  firewallRules =
    lib.optionals (appsCfg.allowExternalCaddyIp != null) (map caddyRule caddyServices)
    ++ map otlpRule otlpSources;
  dockerUserOtlpAdd = ''
    if iptables -L DOCKER-USER -n >/dev/null 2>&1; then
      iptables -I DOCKER-USER -p tcp --dport ${otlpPort} -j DROP
      ${lib.concatMapStrings (source: ''
      iptables -I DOCKER-USER -s ${lib.escapeShellArg source} -p tcp --dport ${otlpPort} -j RETURN
    '') (otlpSources ++ ["127.0.0.1/32" "172.16.0.0/12"])}
    fi
  '';
  dockerUserOtlpDel = ''
    if iptables -L DOCKER-USER -n >/dev/null 2>&1; then
      ${lib.concatMapStrings (source: ''
      iptables -D DOCKER-USER -s ${lib.escapeShellArg source} -p tcp --dport ${otlpPort} -j RETURN || true
    '') (otlpSources ++ ["127.0.0.1/32" "172.16.0.0/12"])}
      iptables -D DOCKER-USER -p tcp --dport ${otlpPort} -j DROP || true
    fi
  '';
in {
  options.homelab.apps = {
    enable = lib.mkEnableOption "homelab Docker app host preparation (M2+)";

    allowExternalCaddyIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "192.168.1.252";
      description = "Legacy Caddy CT 115 IP permitted to reach M2 through M5 app ports before M6 moves Caddy onto this host. Set to null once Caddy runs locally.";
    };
  };

  config = lib.mkIf (cfg.enable && appsCfg.enable) {
    systemd.tmpfiles.rules = [
      "d /opt/homelab 0755 root root -"
      "d /opt/homelab/ca 0755 root root -"
      "d /opt/homelab/executor 0755 root root -"
      "d /opt/homelab/executor/data - - - -"
      "d /opt/homelab/garage-mcp 0755 root root -"
      "d /opt/homelab/garage-mcp/env 0750 root 65532 -"
      "d /opt/homelab/ha-mcp 0755 root root -"
      "d /opt/homelab/ha-mcp/env - - - -"
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
      "d /opt/homelab/immich 0755 root root -"
      "d /opt/homelab/immich/postgres - - - -"
      "d /opt/homelab/immich/redis - - - -"
      "d /opt/homelab/immich/env 0750 root root -"
      "d /opt/homelab/immich-kiosk 0755 root root -"
      "d /opt/homelab/immich-kiosk/config - - - -"
      "d /opt/homelab/signoz 0755 root root -"
      "d /opt/homelab/signoz/data - - - -"
      "d /opt/homelab/signoz/conf 0755 root root -"
      "d /opt/homelab/signoz/env 0750 root root -"
      "d /var/lib/homelab 0755 root root -"
      "d /var/lib/homelab/signoz-clickhouse - - - -"
      "d /var/lib/homelab/signoz-zookeeper - - - -"
      "d /var/cache/homelab 0755 root root -"
      "d /var/cache/homelab/jellyfin - - - -"
      "d /var/cache/homelab/immich-ml - - - -"
    ];

    system.activationScripts.homelabCa = ''
      ${pkgs.coreutils}/bin/install -Dm644 ${../homelab-ca/caddy-local-root.crt} /opt/homelab/ca/caddy-local-root.crt && (
        bundle=$(${pkgs.coreutils}/bin/mktemp /opt/homelab/ca/.homelab-ca-bundle.XXXXXX) || exit 1
        trap '${pkgs.coreutils}/bin/rm -f "$bundle"' EXIT
        ${pkgs.coreutils}/bin/cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt ${../homelab-ca/caddy-local-root.crt} > "$bundle" &&
          ${pkgs.coreutils}/bin/chmod 0644 "$bundle" &&
          ${pkgs.coreutils}/bin/mv -fT "$bundle" /opt/homelab/ca/homelab-ca-bundle.crt
      )
    '';

    homelab.backups.paths = ["/opt/homelab"];

    networking.firewall = {
      allowedTCPPorts = [
        cfg.topology.services.jellyfin.port
        cfg.topology.services.kiosk.port
      ];
      extraCommands =
        lib.concatMapStrings (rule: ''
          iptables -A nixos-fw ${rule}
        '')
        firewallRules
        + dockerUserOtlpAdd;
      extraStopCommands =
        lib.concatMapStrings (rule: ''
          iptables -D nixos-fw ${rule} || true
        '')
        firewallRules
        + dockerUserOtlpDel;
    };
  };
}
