{
  programs.nvf.settings.vim = {
    options = let
      indentWidth = 2;
    in {
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
  };
}
