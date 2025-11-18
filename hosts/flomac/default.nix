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
    };

    # CLI tools that work better from Homebrew
    brews = [
      "mas" # Mac App Store CLI
    ];

    # GUI Applications (casks)
    casks = [
      "1password"
      "brave-browser"
      "bruno"
      "chatgpt"
      "claude"
      "figma"
      "ghostty"
      "google-drive"
      "jordanbaird-ice"
      "karabiner-elements"
      "openlens"
      "orbstack"
      "raycast"
      "shottr"
      "superwhisper"
      "yaak"
      "zoom"
    ];

    # Mac App Store apps (requires mas)
    masApps = {
      # "Xcode" = 497799835; # Too large, install manually if needed
      "Amphetamine" = 937984704;
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
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
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
    vim
  ];
}
