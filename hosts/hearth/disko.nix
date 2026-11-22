let
  mountOptions = ["compress=zstd" "noatime"];
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
                mountpoint = "/var/lib";
                inherit mountOptions;
              };
              "@opt" = {
                mountpoint = "/opt";
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
}
