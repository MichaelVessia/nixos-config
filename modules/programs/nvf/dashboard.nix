{
  programs.nvf.settings.vim.dashboard = {
    startify = {
      enable = true;

      bookmarks = [
        {
          p = "~/Projects/";
        }
        {
          n = "~/nixos-config/";
        }
      ];

      changeDirCmd = "tcd";
      changeToDir = true;
      changeToVCRoot = false;
      disableOnStartup = false;
      filesNumber = 5;
      paddingLeft = 4;
      sessionAutoload = false;
      sessionDeleteBuffers = true;
      sessionDir = "~/config/nvim/session";
      sessionPersistence = false;
      unsafe = false;
      updateOldFiles = true;

      commands = [
        {
          f = "FzfLua files";
        }
        {
          g = "FzfLua grep_live";
        }
        {
          r = "FzfLua registers";
        }
      ];

      lists = [
        {
          header = [
            "Commands"
          ];
          type = "commands";
        }
        {
          header = [
            "Bookmarks"
          ];
          type = "bookmarks";
        }
        {
          header = [
            "Recent Files"
          ];
          type = "files";
        }
        {
          header = [
            "Recent Files in Directory"
          ];
          type = "dir";
        }
      ];

      customHeader = [
        "                                        /$$           "
        "                                       |__/           "
        " /$$    /$$ /$$$$$$   /$$$$$$$ /$$$$$$$ /$$  /$$$$$$  "
        "|  $$  /$$//$$__  $$ /$$_____//$$_____/| $$ |____  $$ "
        " \\  $$/$$/| $$$$$$$$|  $$$$$$|  $$$$$$ | $$  /$$$$$$$ "
        "  \\  $$$/ | $$_____/ \\____  $$\\____  $$| $$ /$$__  $$ "
        "   \\  $/  |  $$$$$$$ /$$$$$$$//$$$$$$$/| $$|  $$$$$$$ "
        "    \\_/    \\_______/|_______/|_______/ |__/ \\_______/ "
        "                                                      "
        "                                                      "
      ];
    };
  };
}
