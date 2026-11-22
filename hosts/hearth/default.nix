{
  lib,
  pkgs,
  username,
  ...
}: let
  personalSshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r michaelvessia@framework13"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINXfbQ30QBeY6SUElJIU3ZSXo5cdpNkfVfr1PrgdSwlc michaelvessia@forge"
  ];
in {
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/homelab
    ../../modules/homelab-ca/nixos.nix
    ../../modules/host-metrics.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  # Jellyfin runs as UID 100000 and needs access to the render node.
  services.udev.extraRules = ''
    KERNEL=="renderD*", MODE="0666"
  '';

  # Pin the onboard Realtek NIC by MAC so eno1 never drifts across kernels.
  systemd.network.links."10-eno1" = {
    matchConfig.MACAddress = "b0:41:6f:16:b1:95";
    linkConfig.Name = "eno1";
  };

  networking = {
    hostName = "hearth";
    useDHCP = false;
    interfaces.eno1.ipv4.addresses = [
      {
        address = "192.168.1.200";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.1.1";
    nameservers = ["127.0.0.1" "1.1.1.1"];
  };
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  systemd.targets = lib.genAttrs ["sleep" "suspend" "hibernate" "hybrid-sleep"] (_: {
    enable = false;
  });

  sops = {
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    gnupg.sshKeyPaths = [];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = personalSshKeys;
  users.users.${username} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = ["wheel" "docker" "video" "render"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = personalSshKeys;
  };
  programs.zsh.enable = true;

  services.tailscale = {
    enable = true;
    extraSetFlags = ["--accept-routes=false" "--operator=${username}"];
  };

  homelab = {
    enable = true;
    role = "permanent";
    hostIp = "192.168.1.200";
    gpu = "amd";
    nfs.enable = true;
    backups.enable = true;
    frame.enable = true;
    apps = {
      enable = true;
      allowExternalCaddyIp = null;
    };
    caddy = {
      enable = true;
      proxmoxUpstream = null;
      syncthingUpstream = "127.0.0.1:8384";
      aliasInterface = "eno1";
      legacyAliases = [
        {
          ip = "192.168.1.147";
          port = 8080;
          upstream = "192.168.1.200:8080";
        }
      ];
    };
    adguard.enable = true;
    tailscale.enable = true;
    syncthing.enable = true;
    homeassistant = {
      enable = true;
      parentInterface = "eno1";
      usbDevices = [
        {
          vendorId = "0658";
          productId = "0200";
        }
      ];
    };
  };

  environment.enableAllTerminfo = true;
  environment.systemPackages = with pkgs; [curl git jq nano rsync vim];

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    accept-flake-config = true;
    extra-substituters = ["https://cache.numtide.com"];
    extra-trusted-public-keys = ["niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="];
  };

  system.stateVersion = "26.05";
}
