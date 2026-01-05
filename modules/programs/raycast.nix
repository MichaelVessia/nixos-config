# Raycast configuration (macOS only)
# Raycast keybinds are managed in the Raycast app, not via Nix.
# This file documents our keybind conventions.
#
# Keybinds (configured in Raycast as Quicklinks/Hotkeys):
#   Ctrl+O  Obsidian    obsidian://open?vault=flo-notes
#   Ctrl+B  Browser
#   Ctrl+C  Claude
#   Ctrl+T  Terminal
{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  # Raycast is installed via Homebrew (not Nix)
  # No declarative config available
}
