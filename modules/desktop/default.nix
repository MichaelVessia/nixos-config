# Desktop Environment Module
# To switch desktop environments, comment/uncomment the desired import
{
  imports = [
    # KDE Plasma 6
    ./plasma.nix

    # To use a different DE (e.g., Hyprland), comment out plasma.nix above
    # and add the new DE module import here:
    # ./hyprland.nix
  ];
}
