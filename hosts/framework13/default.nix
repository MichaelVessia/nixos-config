# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Desktop Environment (change DE in modules/desktop/default.nix)
    ../../modules/desktop
    # Hardware
    ../../modules/hardware/printing.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable aarch64 emulation for cross-compiling Pi images
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "framework13"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable CUPS to print documents (configured in modules/hardware/printing.nix)

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;
      extraConfig = {
        # Force duplex profile (output + input) for built-in audio
        "50-alsa-config" = {
          "monitor.alsa.rules" = [
            {
              matches = [{"device.name" = "alsa_card.pci-0000_00_1f.3";}];
              actions = {
                update-props = {
                  "api.acp.auto-profile" = false;
                  "device.profile" = "output:analog-stereo+input:analog-stereo";
                };
              };
            }
          ];
        };
      };
    };
  };

  # Audio tools for debugging
  environment.systemPackages = with pkgs; [
    pavucontrol
    alsa-utils
  ];

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.michaelvessia = {
    isNormalUser = true;
    description = "Michael Vessia";
    extraGroups = ["networkmanager" "wheel" "docker" "ydotool" "input"];
    shell = pkgs.zsh;
  };

  # Enable zsh system-wide (required for login shell)
  programs.zsh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # Ghostty cachix cache for nightly builds
    extra-substituters = ["https://ghostty.cachix.org"];
    extra-trusted-public-keys = ["ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  #environment.systemPackages = with pkgs; [
  #];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/12th-gen-intel
  services.fwupd.enable = true;

  # Enable Docker
  virtualisation.docker.enable = true;

  # Tailscale VPN
  services.tailscale.enable = true;

  # ydotool for keyboard/mouse automation
  programs.ydotool.enable = true;

  # nh - nix helper for better CLI experience
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 7d --keep 3";
    flake = "/home/michaelvessia/nixos-config";
  };

  # Steam gaming client
  programs.steam.enable = true;

  # nix-ld - run dynamically linked binaries (e.g., workerd for Cloudflare dev)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Libraries for Handy speech-to-text AppImage
    alsa-lib
    openssl
    gtk3
    webkitgtk_4_1
    libayatana-appindicator
    librsvg
    glib
    gdk-pixbuf
    cairo
    pango
    libsoup_3
    fribidi
    harfbuzz
    fontconfig
    freetype
    libGL
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXi
    xorg.libXrender
    xorg.libXtst
    libxkbcommon
    mesa
    libgbm
    libdrm
    vulkan-loader
  ];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
