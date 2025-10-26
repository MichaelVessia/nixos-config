{
  programs.nvf.settings.vim = {
    fzf-lua = {
      enable = true;
      setupOpts.profile = "fzf-native";
    };

    keymaps = [
      {
        key = "<leader> ";
        mode = "n";
        action = ":FzfLua files<CR>";
        desc = "Find files";
      }
      {
        key = "<leader>sg";
        mode = "n";
        action = ":FzfLua live_grep<CR>";
        desc = "Search grep";
      }
      {
        key = "<leader>sr";
        mode = "n";
        action = ":FzfLua registers<CR>";
        desc = "Search Registers";
      }
      {
        key = "<leader>s/";
        mode = "n";
        action = ":FzfLua builtin<CR>";
        desc = "Search Builtin pickers";
      }
    ];
  };
}
