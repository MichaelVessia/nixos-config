{
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
in {
  options.homelab.syncthing.enable = lib.mkEnableOption "homelab Syncthing server (restoring proxmox-syncthing identity)";

  config = lib.mkIf (cfg.enable && cfg.syncthing.enable) {
    services.syncthing = {
      enable = true;
      user = "syncthing";
      group = "syncthing";
      dataDir = "/var/lib/syncthing";
      configDir = "/var/lib/syncthing/config";
      guiAddress = "127.0.0.1:${toString cfg.topology.services.syncthing.uiPort}";
      openDefaultPorts = true;
      overrideDevices = false;
      overrideFolders = false;
    };

    homelab.backups.paths = ["/var/lib/syncthing/config"];
  };
}
