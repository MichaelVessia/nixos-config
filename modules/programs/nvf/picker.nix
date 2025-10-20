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
        desc = "Live grep";
      }
      {
        key = "<leader>s/";
        mode = "n";
        action = ":FzfLua builtin<CR>";
        desc = "Builtin pickers";
      }
    ];
  };
}
