{
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
  nas = cfg.topology.nas;
  activeMounts =
    (lib.attrValues nas.mounts)
    ++ lib.optional cfg.backups.enable nas.backupMount;
  mkNfsMount = mount: {
    name = mount.mountPoint;
    value = {
      device = "${nas.ip}:${mount.export}";
      fsType = "nfs4";
      options =
        [
          "vers=4.1"
          "_netdev"
          "x-systemd.automount"
          "bg"
          "nofail"
        ]
        ++ lib.optional mount.readOnly "ro";
    };
  };
in {
  options.homelab.nfs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mount Synology NFS exports for homelab services.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.nfs.enable) {
    boot.supportedFilesystems = ["nfs"];

    fileSystems = lib.listToAttrs (map mkNfsMount activeMounts);
  };
}
