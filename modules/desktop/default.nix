# Desktop Environment Module
# Multiple DEs can coexist. SDDM shows all available sessions at login.
{
  imports = [
    # KDE Plasma 6
    ./plasma.nix

    # Niri scrollable-tiling Wayland compositor
    ./niri.nix
  ];
}
