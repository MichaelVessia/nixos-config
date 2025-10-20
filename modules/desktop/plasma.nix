# KDE Plasma 6 Desktop Environment Configuration
# System-level configuration for Plasma
{
  config,
  pkgs,
  ...
}: {
  # Enable the X11 windowing system infrastructure
  # Note: Despite the name, this is required for SDDM even when using Wayland
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Note: Plasma 6 uses Wayland by default on NixOS
  # User-specific Plasma configuration (keybinds, themes, etc.) is in modules/programs/plasma.nix
}
