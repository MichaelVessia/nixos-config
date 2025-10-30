{
  programs.nvf.settings.vim = {
    utility = {
      oil-nvim = {
        enable = true;

        setupOpts = {
          default_file_explorer = true;
          constrain_cursor = "editable";
          skip_confirm_for_simple_edits = true;
          prompt_save_on_select_new_entry = true;
          delete_to_trash = true;
          watch_for_changes = false;
          columns = ["icon"];
          view_options = {
            show_hidden = false;
          };
          float = {
            padding = 3;
            border = "rounded";
          };
        };
      };
      preview = {
        glow = {
          # good for inline
          enable = true;
          mappings = {
            openPreview = "<leader>pi";
          };
        };
        markdownPreview = {
          enable = true;
        };
      };

      snacks-nvim = {
        enable = true;
        setupOpts = {
          picker.enable = false; # Using fzf-lua

          bigfile.enable = true;
          explorer.enable = true;
          image.enable = true;
          notifier.enable = true;
        };
      };
    };
    # Keymaps that it wouldnt let me define inline with the plugin
    keymaps = [
      {
        key = "<leader>po";
        desc = "Open markdown preview";
        mode = "n";
        action = ":MarkdownPreview<CR>";
      }
      {
        key = "-";
        desc = "Open oil-nvim interactive file explorer buffer.";
        mode = "n";
        lua = true;
        action = "require('oil').open";
      }
      {
        key = "<leader>e";
        desc = "Explorer";
        mode = "n";
        lua = true;
        action = "function() Snacks.explorer() end";
      }
    ];
  };
}
