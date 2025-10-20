{
config,
pkgs,
lib,
inputs,
...
}:
{
  # Import the nvf Home Manager module
  imports = [
    inputs.nvf.homeManagerModules.default
  ];

  programs.nvf = {
    enable = true;
    # your settings need to go into the settings attribute set
    # most settings are documented in the appendix
    settings = {
      vim = {
        options =
          let
            indentWidth = 2;
          in
            {
            autoindent = true;
            shiftwidth = indentWidth;
            tabstop = indentWidth;

            # backup & swap
            backup = false;
            writebackup = false;
            swapfile = false;

            # mouse
            mouse = "nv";
            mousemodel = "extend";
          };

        clipboard = {
          enable = true;
          registers = "unnamedplus";
        };

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
            desc = "Search / grep";
          }
          {
            key = "<leader>s/";
            mode = "n";
            action = ":FzfLua builtin<CR>";
            desc = "Builtin pickers";
          }
        ];

        utility = {
          oil-nvim.enable = true;
        };
        binds = {
          whichKey.enable = true;
          cheatsheet.enable = true;
        };
        git = {
          enable = true;
          gitsigns.enable = true;
          gitsigns.codeActions.enable = false;
        };
        languages = {
          enableTreesitter = true;
          enableExtraDiagnostics = true;
          bash.enable = true;
          go = {
            enable = true;
            lsp.enable = true;
          };
          html.enable = true;
          markdown.enable = true;
          nix.enable = true;
          python.enable = true;
          ruby.enable = true;
          svelte.enable = true;
          tailwind.enable = true;
          ts.enable = true;
        };
        lsp = {
          enable = true;
          formatOnSave = true;
          lightbulb.enable = true;
          trouble.enable = true;
        };
        statusline.lualine = {
          enable = true;
          theme = "catppuccin";
        };
        terminal = {
          toggleterm = {
            enable = true;
            lazygit.enable = true;
          };
        };
        theme = {
          enable = true;
          name = "catppuccin";
          style = "mocha";
        };
        viAlias = false;
        vimAlias = true;
      };
    };
  };
}
