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
      python3 # needed for claude-code plugins (hookify)
      ripgrep # recursively searches directories for a regex pattern
      jq # A lightweight and flexible command-line JSON processor
      yq-go # yaml processor https://github.com/mikefarah/yq
      fd # find replacement
      ncdu # disk usage
      curl
      wget
      git-town
      jira-cli-go # Jira CLI
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
      (pkgs.writeShellScriptBin "critique" ''
        export PATH="${pkgs.bun}/bin:$PATH"
        exec bunx critique "$@"
      '') # git diff viewer
      (pkgs.writeShellScriptBin "datadog" ''
        export PATH="${pkgs.bun}/bin:$PATH"
        exec bunx @ctdio/datadog-cli "$@"
      '') # datadog CLI
      lazydocker # terminal UI for docker
      lsof # list open files

      inputs.claude-code.packages.${pkgs.system}.default
      inputs.beads.packages.${pkgs.system}.default # bd - AI-friendly issue tracker
      inputs.opencode.packages.${pkgs.system}.default # AI coding agent
    ]
    ++ lib.optionals stdenv.isLinux [
      signal-desktop # secure messaging
      wl-clipboard # clipboard provider for wayland (required for neovim clipboard integration)
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
