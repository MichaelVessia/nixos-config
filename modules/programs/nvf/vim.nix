{
  programs.nvf.settings.vim = {
    viAlias = false;
    vimAlias = true;
    binds = {
      whichKey.enable = true;
      cheatsheet.enable = true;
    };
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
        clipboard = "unnamedplus";
      };
    enableLuaLoader = true;
    spellcheck = {
      enable = true;
      languages = ["en"];
    };
    theme = {
      enable = true;
      name = "catppuccin";
      style = "mocha";
      transparent = true;
    };
    statusline.lualine = {
      enable = true;
      theme = "catppuccin";
    };
  };
}
