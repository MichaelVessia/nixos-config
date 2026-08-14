{...}: {
  programs.nvf.settings.vim.theme = {
    enable = true;
    name = "catppuccin";
    # Let Neovim's native terminal appearance detection select Latte for a
    # light background and Mocha for a dark background.
    style = "auto";
    # Keep Catppuccin's intended contrast instead of blending with the
    # terminal's unrelated background palette.
    transparent = false;
  };
}
