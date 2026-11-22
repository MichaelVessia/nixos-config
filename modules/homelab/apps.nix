{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  appsCfg = cfg.apps;
  caddyServices = ["homepage" "uptimekuma" "executor"];
  caddyRule = service: "-s ${lib.escapeShellArg appsCfg.allowExternalCaddyIp} -p tcp --dport ${toString cfg.topology.services.${service}.port} -j nixos-fw-accept";
in {
  options.homelab.apps = {
    enable = lib.mkEnableOption "homelab Docker app host preparation (M2+)";

    allowExternalCaddyIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "192.168.1.252";
      description = "Legacy Caddy CT 115 IP permitted to reach M2 app ports before M6 moves Caddy onto this host. Set to null once Caddy runs locally.";
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
      "d /opt/homelab/executor 0750 root root -"
      "d /opt/homelab/executor/data 0750 root root -"
      "d /opt/homelab/garage-mcp 0750 root root -"
      "d /opt/homelab/signoz-mcp 0750 root root -"
    ];

    system.activationScripts.homelabCa = ''
      ${pkgs.coreutils}/bin/install -Dm644 ${../homelab-ca/caddy-local-root.crt} /opt/homelab/ca/caddy-local-root.crt
    '';

    homelab.backups.paths = ["/opt/homelab"];

    networking.firewall = lib.mkIf (appsCfg.allowExternalCaddyIp != null) {
      extraCommands =
        lib.concatMapStrings (service: ''
          iptables -A nixos-fw ${caddyRule service}
        '')
        caddyServices;
      extraStopCommands =
        lib.concatMapStrings (service: ''
          iptables -D nixos-fw ${caddyRule service} || true
        '')
        caddyServices;
    };
  };
}
