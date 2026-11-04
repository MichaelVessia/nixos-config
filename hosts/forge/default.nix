{
  config,
  inputs,
  pkgs,
  ...
}: let
  # The shared pkgs-unstable does not allow unfree packages, which the CUDA
  # build of Sunshine needs.
  pkgs-unstable-unfree = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in {
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop-system.nix
    ../../modules/host-metrics.nix
  ];

  networking.hostName = "forge";
  system.stateVersion = "26.05";

  # Trust this host's portless CA for floai `mono pitch verify`. `portless trust`
  # cannot update the NixOS trust store. Replace the file if ~/.portless/ca.pem changes.
  security.pki.certificateFiles = [./portless-ca.crt];

  services.openssh.enable = true;
  users.users.michaelvessia = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP8SJbl7L0SDb3HveKQNN+TAoyq9/aHFEBHm4mBGhfWG foundry"
    ];
  };

  # The desktop is already on the advertised homelab subnet. Accepting that
  # route sends LAN replies through Tailscale instead of the Ethernet interface.
  services.tailscale.extraSetFlags = [
    "--accept-routes=false"
    "--operator=michaelvessia"
  ];
  systemd.services.tailscale-accept-routes.enable = false;

  # Game streaming host for Moonlight clients (Fire TV). NVENC needs the CUDA
  # build, which nixpkgs disables by default. Take it from unstable for
  # security fixes that 26.05 does not have. Use Wayland screencopy capture
  # on niri without the CAP_SYS_ADMIN wrapper.
  services.sunshine = {
    enable = true;
    package = pkgs-unstable-unfree.sunshine.override {cudaSupport = true;};
    autoStart = true;
    capSysAdmin = false;
    openFirewall = true;
    settings = {
      capture = "wlr";
      # Stream the ONN monitor. Sessions match by output name, not by index.
      output_name = "DP-2";
      # niri opens windows and sends controller input on the focused monitor.
      global_prep_cmd = builtins.toJSON [
        {
          do = "niri msg action focus-monitor DP-2";
          undo = "";
        }
      ];
    };
  };

  # NVIDIA PCI device 10de:1e84 (Turing). Use the proprietary driver with Wayland modesetting.
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
