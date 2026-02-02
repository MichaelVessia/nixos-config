{...}: {
  programs.nvf.settings.vim = {
    utility.smart-splits = {
      enable = true;
      setupOpts = {
        ignored_filetypes = ["NvimTree" "neo-tree"];
        multiplexer_integration = "tmux";
      };
    };

    keymaps = [
      # Navigate between nvim splits and tmux panes
      {
        key = "<C-h>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').move_cursor_left";
        desc = "Move to left split/pane";
      }
      {
        key = "<C-j>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').move_cursor_down";
        desc = "Move to below split/pane";
      }
      {
        key = "<C-k>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').move_cursor_up";
        desc = "Move to above split/pane";
      }
      {
        key = "<C-l>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').move_cursor_right";
        desc = "Move to right split/pane";
      }
      # Resize splits
      {
        key = "<M-h>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').resize_left";
        desc = "Resize split left";
      }
      {
        key = "<M-j>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').resize_down";
        desc = "Resize split down";
      }
      {
        key = "<M-k>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').resize_up";
        desc = "Resize split up";
      }
      {
        key = "<M-l>";
        mode = "n";
        lua = true;
        action = "require('smart-splits').resize_right";
        desc = "Resize split right";
      }
    ];
  };
}
