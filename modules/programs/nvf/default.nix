{
config,
pkgs,
lib,
inputs,
...
}:
{
  imports = [
    inputs.nvf.homeManagerModules.default
    ./picker.nix
    ./oil.nix
    ./vim.nix
  ];

  programs.nvf = {
    enable = true;
    # your settings need to go into the settings attribute set
    # most settings are documented in the appendix
    settings = {
      vim = {

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
