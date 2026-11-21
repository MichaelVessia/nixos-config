{
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
  frameCfg = cfg.frame;
in {
  options.homelab.frame = {
    enable = lib.mkEnableOption "garage-frame host preparation";
  };

  config = lib.mkIf (cfg.enable && frameCfg.enable) {
    systemd.tmpfiles.rules = [
      "d /opt/garage-frame 0755 root root -"
    ];

    networking.firewall.allowedTCPPorts = [
      cfg.topology.services.frame.port
    ];

    homelab.backups.paths = [
      "/opt/garage-frame"
    ];
  };
}
