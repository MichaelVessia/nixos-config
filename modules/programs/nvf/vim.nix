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
    formatter.conform-nvim = {
      enable = true;
      setupOpts = {
        formatters_by_ft = {
          typescript = [
            "biome"
            "eslint_d"
          ];
          javascript = [
            "biome"
            "eslint_d"
          ];
        };
      };
    };
    diagnostics = {
      enable = true;
      nvim-lint.enable = true;
      config = {
        virtual_text = true;
      };
    };
  };
}
