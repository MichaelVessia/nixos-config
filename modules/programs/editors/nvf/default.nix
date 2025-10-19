{ config, lib, ... }:

{
  programs.nvf.enable = true;
  programs.nvf.settings.vim = {
    enableLuaLoader = true;
    syntaxHighlighting = true;
    lineNumberMode = "relNumber";
    viAlias = false;
    vimAlias = true;
    preventJunkFiles = true;

    undoFile.enable = true;
    notify.nvim-notify.enable = true;
    projects.project-nvim.enable = true;
    globals.editorconfig = true;

    options = {
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      autoindent = true;
      exrc = true;
      secure = true;
      mouse = ""; # disable mouse
    };

    clipboard = {
      enable = true;
      providers.wl-copy.enable = true;
      registers = "unnamedplus";
    };

    autopairs.nvim-autopairs = {
      enable = true;
    };

    binds = {
      cheatsheet.enable = true;
      whichKey.enable = true;
    };

    dashboard = {
      dashboard-nvim.enable = false;
      alpha.enable = true;
    };

    statusline.lualine = {
      enable = true;
      globalStatus = true;
      icons.enable = true;
    };
  };
}
