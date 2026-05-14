{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  # Packages that should be installed to the user profile.
  home.packages = with pkgs;
    [
      fastfetch
      yazi

      # archives
      zip
      xz
      unzip
      p7zip

      # utils
      bun
      python3 # needed for claude-code plugins (hookify)
      ripgrep # recursively searches directories for a regex pattern
      ast-grep # structural search and replace
      jq # A lightweight and flexible command-line JSON processor
      yq-go # yaml processor https://github.com/mikefarah/yq
      fd # find replacement
      ncdu # disk usage
      curl
      wget
      git-town
      jira-cli-go # Jira CLI
      (pkgs.callPackage ./linear-cli {}) # Linear CLI
      lefthook
      # Note: atuin, zoxide, fzf, eza, and bat are configured as programs in shell.nix for shell integration

      # networking tools
      mtr # A network diagnostic tool
      iperf3
      dnsutils # `dig` + `nslookup`
      ldns # replacement of `dig`, it provide the command `drill`
      nmap # A utility for network discovery and security auditing
      ipcalc # it is a calculator for the IPv4/v6 addresses

      # misc
      file
      which
      tree
      gnused
      gnutar
      gawk
      zstd
      gnupg

      # nix related
      #
      # it provides the command `nom` works just like `nix`
      # with more details log output
      nix-output-monitor
      nh # nix helper - better CLI for nixos-rebuild/darwin-rebuild
      devbox # portable development environments
      devenv # developer environments with nix

      # productivity
      glow # markdown previewer in terminal
      bitwarden-desktop # password manager
      obsidian # note-taking and knowledge management
      dbeaver-bin # database management tool
      # Note: whisper-cpp is configured in transcribe.nix
      # Note: syncthing is configured as a service in syncthing.nix

      # terminal emulators
      tmux

      btop # replacement of htop/nmon
      difftastic # structural git diff viewer
      lazygit # terminal UI for git
      lazydocker # terminal UI for docker
      lsof # list open files

      inputs.llm-agents.packages.${pkgs.system}.beads-viewer
      inputs.llm-agents.packages.${pkgs.system}.claude-code
      inputs.llm-agents.packages.${pkgs.system}.codex
      inputs.llm-agents.packages.${pkgs.system}.handy
      inputs.llm-agents.packages.${pkgs.system}.opencode
      inputs.llm-agents.packages.${pkgs.system}.pi
      inputs.llm-agents.packages.${pkgs.system}.qmd
      inputs.llm-agents.packages.${pkgs.system}.rtk
      inputs.wiggle-puppy.packages.${pkgs.system}.default
      (pkgs.callPackage ./ralph {})
      (pkgs.callPackage ./td {}) # task tracking for AI coding sessions
    ]
    ++ lib.optionals stdenv.isDarwin [
      pngpaste # grab images from clipboard
      (pkgs-unstable.callPackage ./pup {}) # Datadog API CLI; needs newer rustc than 25.11 ships
      (pkgs.callPackage ./rootly {}) # Rootly incident management CLI
    ]
    ++ lib.optionals stdenv.isLinux [
      signal-desktop # secure messaging
      wl-clipboard # clipboard provider for wayland (required for neovim clipboard integration)
      xclip # X11 clipboard provider
      # Note: ydotool is enabled via programs.ydotool and used by Handy for text input
      iotop # io monitoring
      iftop # network monitoring
      strace # system call monitoring
      ltrace # library call monitoring
      sysstat
      lm_sensors # for `sensors` command
      ethtool
      pciutils # lspci
      usbutils # lsusb
    ];
}
