{
  programs.nvf.settings.vim = {
    viAlias = false;
    vimAlias = true;
    enableLuaLoader = true;
    autocomplete.blink-cmp.enable = true;
    autocomplete.blink-cmp.setupOpts = {
      keymap = {
        preset = "default";
        "<C-n>" = ["select_next"];
        "<C-p>" = ["select_prev"];
        "<Tab>" = ["fallback"];
        "<S-Tab>" = ["fallback"];
      };
    };
    formatter.conform-nvim.enable = true;
    diagnostics.nvim-lint.enable = true;
  };
}
