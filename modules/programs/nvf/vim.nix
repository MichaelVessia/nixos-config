{
  programs.nvf.settings.vim = {
    viAlias = false;
    vimAlias = true;
    enableLuaLoader = true;
    # TODO: Switch back to blink-cmp when macOS arm64 build issue is fixed
    # Current issue: blink-cmp-fuzzy fails to link Lua symbols on macOS arm64
    # Tracked at: https://github.com/Saghen/blink.cmp/issues/652
    autocomplete.nvim-cmp.enable = true;
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
