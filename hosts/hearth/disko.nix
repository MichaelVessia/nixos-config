{lib, ...}: let
  mountOptions = ["compress=zstd" "noatime"];
  snapshotVolumes = {
    opt = "/opt";
    var-lib = "/var/lib";
  };
in {
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-512GB_SSD_MQ18B35505237";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        swap = {
          size = "8G";
          content.type = "swap";
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = ["-f"];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                inherit mountOptions;
              };
              "@nix" = {
                mountpoint = "/nix";
                inherit mountOptions;
              };
              "@var-lib" = {
                mountpoint = snapshotVolumes.var-lib;
                inherit mountOptions;
              };
              "@opt" = {
                mountpoint = snapshotVolumes.opt;
                inherit mountOptions;
              };
              "@home" = {
                mountpoint = "/home";
                inherit mountOptions;
              };
            };
          };
        };
      };
    };
  };

  services.snapper.configs =
    lib.mapAttrs (_: mountPoint: {
      SUBVOLUME = mountPoint;
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 24;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 0;
      TIMELINE_LIMIT_YEARLY = 0;
      NUMBER_CLEANUP = true;
    })
    snapshotVolumes;

  systemd.tmpfiles.rules = map (mountPoint: "v ${mountPoint}/.snapshots 0750 root root -") (lib.attrValues snapshotVolumes);
}
