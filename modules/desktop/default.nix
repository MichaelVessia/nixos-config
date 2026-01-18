# Desktop Environment Module
# Multiple DEs can coexist. SDDM shows all available sessions at login.
{
  imports = [
    # Niri scrollable-tiling Wayland compositor
    ./niri.nix
  ];
}
