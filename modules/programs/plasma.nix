# KDE Plasma User Configuration (Home-Manager)
#
# This file contains USER-LEVEL Plasma settings:
#   - Keyboard shortcuts
#   - Themes and appearance (within plasma-manager)
#   - Application-specific settings
#   - Keybinds and custom shortcuts
#   - Panel configurations
#   - Widget settings
#
# For SYSTEM-LEVEL Plasma settings, see: modules/desktop/plasma.nix
#   - Enabling Plasma itself (services.desktopManager.plasma6)
#   - Display manager (SDDM)
#   - System services
#
# Use rc2nix via nix run github:nix-community/plasma-manager to generate a file from what changed in the GUI
# From I have extracted things that I have manually set, to be persisted here
{
  programs.plasma = {
    enable = true;
    shortcuts = {
      kwin = {
        "Switch to Desktop 1" = "Meta+1";
        "Switch to Desktop 2" = "Meta+2";
        "Switch to Desktop 3" = "Meta+3";
        "Switch to Desktop 4" = "Meta+4";
        "Switch to Desktop 5" = "Meta+5";
        "Switch to Desktop 6" = "Meta+6";
        "Switch to Desktop 7" = "Meta+7";
        "Switch to Desktop 8" = "Meta+8";
        "Switch to Desktop 9" = "Meta+9";
        "Window to Desktop 1" = "Meta+!";
        "Window to Desktop 2" = "Meta+@";
        "Window to Desktop 3" = "Meta+#";
        "Window to Desktop 4" = "Meta+$";
        "Window to Desktop 5" = "Meta+%";
        "Window to Desktop 6" = "Meta+^";
        "Window to Desktop 7" = "Meta+&";
        "Window to Desktop 8" = "Meta+*";
        "Window to Desktop 9" = "Meta+(";
      };
    };

    configFile = {
      kcminputrc.Keyboard = {
        RepeatDelay = 200;
        RepeatRate = 40;
      };

      kdeglobals.General = {
        BrowserApplication = "brave-browser.desktop";
        TerminalApplication = "ghostty";
        TerminalService = "com.mitchellh.ghostty.desktop";
      };

      kwinrc = {
        Desktops = {
          Id_1 = "bd220e45-9b26-48a8-a5f6-78ef71b8c442";
          Number = 8;
          Rows = 2;
        };
        Plugins.slideEnabled = false;
      };
    };

    dataFile = {};
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
      "text/plain" = "nvim.desktop";
    };
  };
}
