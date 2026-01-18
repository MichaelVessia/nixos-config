# Niri Wayland Compositor - System Level Configuration
# Only adds system packages and services.
# Niri itself is enabled via home-manager (modules/programs/niri.nix).
{
  config,
  pkgs,
  inputs,
  ...
}: {
  nixpkgs.overlays = [inputs.niri.overlays.niri];

  # XWayland support for X11 apps, shell tools
  environment.systemPackages = with pkgs; [
    niri-unstable
    xwayland-satellite
    swaybg
    swaylock
    swayidle
    brightnessctl
    playerctl
    nautilus
  ];

  # Register niri as a session for SDDM
  services.displayManager.sessionPackages = [pkgs.niri-unstable];

  # Portal configuration for screen sharing
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["gnome" "gtk"];
  };

  # Use gnome-keyring for secrets
  services.gnome.gnome-keyring.enable = true;

  # Polkit agent for authentication dialogs
  security.polkit.enable = true;
}
