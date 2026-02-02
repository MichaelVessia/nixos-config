# nixos-config

NixOS and nix-darwin configuration managed with flakes.

## Tmux Configuration

Tmux config lives in `modules/programs/shell.nix` under `programs.tmux.extraConfig`.

**Important**: When adding or modifying tmux keybindings, always update the help
popup (bound to `prefix + ?`) to reflect the changes. The popup is defined in
the same `extraConfig` block.
