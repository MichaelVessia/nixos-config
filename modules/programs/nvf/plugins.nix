{
  programs.nvf.settings.vim = {
    autocomplete.blink-cmp.enable = true;
    utility.snacks-nvim = {
      enable = true;
      setupOpts = {
        gitbrowse.enable = true;
        notifier.enable = true;
        dashboard = {
          enable = true;
          sections = [
            {section = "header";}
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
          ];
        };
      };
    };
  };
}
