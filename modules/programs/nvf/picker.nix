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
      {
        key = "<leader>sw";
        mode = "n";
        action = ":FzfLua grep_cword<CR>";
        desc = "Search word under cursor";
      }
      {
        key = "<leader>sw";
        mode = "x";
        action = ":FzfLua grep_visual<CR>";
        desc = "Search visual selection";
      }
      {
        key = "<leader>sW";
        mode = "n";
        action = ":FzfLua grep_cWORD<CR>";
        desc = "Search WORD under cursor";
      }
    ];
  };
}
