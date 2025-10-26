{pkgs, ...}: {
  programs.nvf.settings.vim = {
    languages = {
      enableDAP = false;
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;
      typst = {
        enable = true;
        extensions.typst-preview-nvim.enable = true;
        format.type = "typstyle";
        treesitter.enable = true;
      };
      nix = {
        enable = true;
        extraDiagnostics.enable = true;
        treesitter.enable = true;
        format.type = "alejandra";
        lsp = {
          server = "nixd";
          package = pkgs.nixd;
        };
      };
      csharp.enable = true;
      yaml.enable = true;
      markdown.enable = true;
      bash.enable = true;
      clang.enable = true;
      css = {
        enable = true;
        format = {
          type = "prettier";
          package = pkgs.nodePackages.prettier;
        };
      };
      html.enable = true;
      sql.enable = true;
      ts = {
        enable = true;
        format = {
          type = "prettier";
          package = pkgs.nodePackages.prettier;
        };
      };
      go.enable = true;
      lua.enable = true;
      python.enable = true;
    };
  };
}
