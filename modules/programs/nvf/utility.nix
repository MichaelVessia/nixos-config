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
        markdownPreview.enable = true;
      };
    };

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
    ];
  };
}
