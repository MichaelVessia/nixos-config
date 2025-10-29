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
        glow.enable = true;
      };
    };

    keymaps = [
      # {
      #   key = "-";
      #   desc = "Open oil-nvim interactive file explorer float.";
      #   mode = "n";
      #   lua = true;
      #   action = "require('oil').open_float";
      # }
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
