{
  config,
  pkgs,
  username,
  ...
}: {
  # System-level nix-darwin configuration
  # Manages Homebrew and macOS system settings

  # Enable Homebrew management through nix-darwin
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
      # Homebrew now refuses `brew bundle install --cleanup` without explicit
      # confirmation; --force-cleanup skips the prompt for cleanup only.
      extraFlags = ["--force-cleanup"];
    };

    # Third-party taps
    taps = [
      "humanlayer/humanlayer"
      "nkzw-tech/tap" # codiff
      "omnigent-ai/tap"
    ];

    # CLI tools that work better from Homebrew
    brews = [
      "mas" # Mac App Store CLI
      "agent-browser" # Browser automation CLI for AI agents; run `agent-browser install` once post-install to fetch Chrome
      "omnigent"
    ];

    # GUI Applications (casks)
    casks = [
      "1password"
      "bitwarden"
      "brave-browser"
      "bruno"
      "chatgpt"
      "claude"
      "cmux"
      "nkzw-tech/tap/codiff"
      "codex-app"
      "figma"
      "ghostty"
      "hammerspoon"
      "google-drive"
      "handy"
      "humanlayer/humanlayer/humanlayer"
      "jordanbaird-ice"
      "karabiner-elements"
      "linear"
      "openlens"
      "orbstack"
      "protonvpn"
      "raycast"
      "shottr"
      "superwhisper"
      "tailscale-app"
      "libreoffice"
      "yaak"
      "zed"
      "zoom"
    ];

    # Mac App Store apps (requires mas)
    masApps = {
      # "Xcode" = 497799835; # Too large, install manually if needed
      "Amphetamine" = 937984704;
      "Okta Verify" = 490179405;
      "Slack" = 803453959;
    };
  };

  # System configuration
  system = {
    stateVersion = 5;
    primaryUser = username;
    defaults = {
      # Dock settings
      dock = {
        autohide = true;
        orientation = "bottom";
        show-recents = false;
        tilesize = 48;
      };

      # Finder settings
      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };

      # Global macOS settings
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false; # Disable accent popup on key hold
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };

      # Mission Control / Spaces settings
      CustomUserPreferences = {
        "com.apple.dock" = {
          mru-spaces = false; # Don't auto-rearrange Spaces
        };
        "com.apple.spaces" = {
          spans-displays = true; # All monitors switch together (like Plasma)
        };
        # Enable Cmd+1-8 for Mission Control desktop switching
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # Disable Spotlight shortcut (Cmd+Space) - use Raycast instead
            "64" = {enabled = false;};
            # Disable screenshot shortcuts (conflict with move-to-desktop)
            "28" = {enabled = false;}; # Cmd+Shift+3
            "30" = {enabled = false;}; # Cmd+Shift+4
            "184" = {enabled = false;}; # Cmd+Shift+5
            # Switch to Desktop 1-8 (IDs 118-125), modifier 1048576 = Cmd
            "118" = {
              enabled = true;
              value = {
                parameters = [49 18 1048576];
                type = "standard";
              };
            };
            "119" = {
              enabled = true;
              value = {
                parameters = [50 19 1048576];
                type = "standard";
              };
            };
            "120" = {
              enabled = true;
              value = {
                parameters = [51 20 1048576];
                type = "standard";
              };
            };
            "121" = {
              enabled = true;
              value = {
                parameters = [52 21 1048576];
                type = "standard";
              };
            };
            "122" = {
              enabled = true;
              value = {
                parameters = [53 23 1048576];
                type = "standard";
              };
            };
            "123" = {
              enabled = true;
              value = {
                parameters = [54 22 1048576];
                type = "standard";
              };
            };
            "124" = {
              enabled = true;
              value = {
                parameters = [55 26 1048576];
                type = "standard";
              };
            };
            "125" = {
              enabled = true;
              value = {
                parameters = [56 28 1048576];
                type = "standard";
              };
            };
            # Move window to space: handled by Hammerspoon (Cmd+Shift+1-8)
          };
        };
      };
    };
  };

  # Nix configuration
  # Using Determinate Nix, so disable nix-darwin's Nix management
  nix.enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set up user
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Set macOS hostname
  networking = {
    hostName = "flomac";
    computerName = "flomac";
    localHostName = "flomac";
  };

  # Environment variables
  environment.systemPackages = with pkgs; [
    _1password-cli
    coreutils # provides gtimeout, gdate, etc.
    vim
  ];
}
