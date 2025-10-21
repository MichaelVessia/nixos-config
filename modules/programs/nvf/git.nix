{
  programs.nvf.settings.vim = {
    git = {
      enable = true;
      gitsigns.enable = true;
      gitsigns.codeActions.enable = false;
      neogit = {
        enable = true;
        mappings.open = "<leader>G";
      };
    };

    keymaps = [
      {
        key = "<leader>gB";
        mode = "n";
        action = ":Gitsigns blame<CR>";
        desc = "[G]it [B]lame";
      }
      {
        key = "<leader>go";
        mode = ["n" "x"];
        lua = true;
        action = "function() Snacks.gitbrowse() end";
        desc = "[G]it Browse ([O]pen)";
      }
    ];
  };
}
