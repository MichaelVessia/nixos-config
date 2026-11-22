{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
in {
  imports = [
    ./nfs.nix
    ./backups.nix
    ./frame.nix
    ./apps.nix
    ./caddy.nix
    ./homeassistant.nix
    ./adguard.nix
    ./tailscale.nix
  ];

  options.homelab = {
    enable = lib.mkEnableOption "homelab server stack";

    role = lib.mkOption {
      type = lib.types.enum ["bridge" "permanent"];
      default = "permanent";
      description = "Whether this host is the temporary bridge host or the permanent homelab host.";
    };

    hostIp = lib.mkOption {
      type = lib.types.str;
      description = "Primary LAN IPv4 address of the homelab host.";
    };

    gpu = lib.mkOption {
      type = lib.types.enum ["none" "nvidia" "amd"];
      default = "none";
      description = "GPU acceleration profile available on the homelab host.";
    };

    topology = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = builtins.fromJSON (builtins.readFile ./topology.json);
      description = "Parsed homelab topology shared across NixOS modules and external stacks.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = {};

    virtualisation.docker.enable = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      btrfs-progs
      nfs-utils
      restic
      sqlite
    ];
  };
}
