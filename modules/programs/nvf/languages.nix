{
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
  programs.nvf.settings.vim = {
    languages = {
      enableDAP = false;
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;

      # Disable problematic languages
      astro.enable = false;

      # Enable only the languages we want
      typst = {
        enable = true;
        extensions.typst-preview-nvim.enable = true;
        format.type = ["typstyle"];
        treesitter.enable = true;
      };
      nix = {
        enable = true;
        extraDiagnostics.enable = true;
        treesitter.enable = true;
        format.type = ["alejandra"];
        lsp = {
          servers = ["nixd"];
        };
      };
      csharp.enable = false;
      yaml.enable = true;
      markdown.enable = true;
      bash.enable = true;
      clang.enable = true;
      css = {
        enable = true;
        format = {
          type = ["biome"];
        };
      };
      html.enable = true;
      sql.enable = true;
      ts = {
        enable = true;
        treesitter.enable = true;
        format = {
          type = ["biome"];
        };
        lsp = {
          enable = true;
          servers = ["ts_ls"];
        };
        extraDiagnostics.enable = true;
      };
      go.enable = true;
      lua.enable = true;
      python.enable = true;
    };
  };
}
