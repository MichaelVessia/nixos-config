{
  lib,
  pkgs,
  ...
}: {
  programs.nvf.settings.vim = {
     diagnostics = {
      enable = true;
      config = {
        signs = {
          text = {
            "vim.diagnostic.severity.Error" = " ";
            "vim.diagnostic.severity.Warn" = " ";
            "vim.diagnostic.severity.Hint" = " ";
            "vim.diagnostic.severity.Info" = " ";
          };
        };
        underline = true;
        update_in_insert = true;
        virtual_text = {
          format =
            lib.generators.mkLuaInline
            /*
            lua
            */
            ''
              function(diagnostic)
                return string.format("%s", diagnostic.message)
                --return string.format("%s (%s)", diagnostic.message, diagnostic.source)
              end
            '';
        };
      };
      nvim-lint = {
        enable = true;
      };
    };
    syntaxHighlighting = true;
    languages = {
      enableDAP = true;
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;
      go.enable = true;
      ts = {
        enable = true;
        format.package = pkgs.prettierd;
      };
      css = {
        enable = true;
        format.package = pkgs.prettierd;
      };
      html.enable = true;
      bash.enable = true;
      nix.enable = true;
      tailwind.enable = true;
    };
  };
}
