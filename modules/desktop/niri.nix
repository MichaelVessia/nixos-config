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
    swaylock
    swayidle
    brightnessctl
    playerctl
    nautilus
  ];

  # Greetd display manager with tuigreet
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };

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

  # UPower for battery monitoring (required for noctalia battery widget)
  services.upower.enable = true;
}
