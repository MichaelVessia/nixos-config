{config, ...}: {
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

  # Agent builds can fill RAM. Compressed RAM swap keeps the T3 Code server
  # responsive; the SATA swap partition stalls it long enough to drop clients.
  zramSwap.enable = true;

  services.openssh.enable = true;
  users.users.michaelvessia = {
    # Keeps T3 Code's systemd user service running without a login session.
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINhZQaY3xFx3zMord/MUJhPbHur1sVZDkJLNWz9XIZXU michael.vessia@flosports.tv"
    ];
  };

  # The desktop is already on the advertised homelab subnet. Accepting that
  # route sends LAN replies through Tailscale instead of the Ethernet interface.
  services.tailscale.extraSetFlags = [
    "--accept-routes=false"
    "--operator=michaelvessia"
  ];
  systemd.services.tailscale-accept-routes.enable = false;

  # NVIDIA PCI device 10de:1e84 (Turing). Use the proprietary driver with Wayland modesetting.
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
