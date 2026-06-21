{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: let
  garageCliNames = [
    "adguard"
    "autocaliweb"
    "caddy"
    "immich"
    "jellyfin"
    "jellyseerr"
    "prowlarr"
    "radarr"
    "sabnzbd"
    "sonarr"
    "tailscale"
    "tubearchivist"
  ];

  garageBun2nix = inputs.garage.inputs.bun2nix.packages.${pkgs.system}.default;
  garageMissingBunNix = builtins.toFile "garage-bun-missing.nix" ''
    {fetchurl, ...}: {
      "@mpsuesser/oxlint-plugin-effect@0.3.0" = fetchurl {
        url = "https://registry.npmjs.org/@mpsuesser/oxlint-plugin-effect/-/oxlint-plugin-effect-0.3.0.tgz";
        hash = "sha512-2n09UMHywAo+oifH1Tp7o9+uvC9WBc78smQTRlWCusfQw86ECK+7H4ExJGU9WjvMiJzuIw+0Gw2FNUq9vUuqoA==";
      };

      "@oxlint/plugins@1.69.0" = fetchurl {
        url = "https://registry.npmjs.org/@oxlint/plugins/-/plugins-1.69.0.tgz";
        hash = "sha512-4MLUf2a9ai9EymFvcIBvaCkHJkvOA/WHmPhzrTu0cRBYpaaMBxmwwjGTOYdBC149XAwtaL7eaCnojkqxdMvuKg==";
      };

      "effect-oxlint@0.3.2" = fetchurl {
        url = "https://registry.npmjs.org/effect-oxlint/-/effect-oxlint-0.3.2.tgz";
        hash = "sha512-IBCRRtcwP9LQVxHNnA6n7LBcrIFnBcCsUyUWo1fHBJqBUQ/Tj2DcDgiPhf0DnE5ClhJYtXMAKh6Fc/EuaG49hQ==";
      };

      "effect@4.0.0-beta.78" = fetchurl {
        url = "https://registry.npmjs.org/effect/-/effect-4.0.0-beta.78.tgz";
        hash = "sha512-j79Rl9QpHwMz/ZJWLNpZoiVj9N7zHqiLKN5EcYd/A8J1oqejILWQLfc4HPlvqHqKC8SK55LJ+X4gy4ONJ+JpfQ==";
      };
    }
  '';
  garageBunDeps = pkgs.symlinkJoin {
    name = "garage-bun-cache";
    paths = [
      (garageBun2nix.fetchBunDeps {
        bunNix = "${inputs.garage}/bun.nix";
      })
      (garageBun2nix.fetchBunDeps {
        bunNix = garageMissingBunNix;
      })
    ];
  };

  garageCli = name: let
    package = inputs.garage.packages.${pkgs.system}.${name};
    packageWithFixedBunDeps = package.overrideAttrs (_old: {
      bunDeps = garageBunDeps;
    });
  in
    if pkgs.stdenv.hostPlatform.isDarwin
    then
      packageWithFixedBunDeps.overrideAttrs (_old: {
        bunInstallFlags = [
          "--linker=hoisted"
          "--backend=copyfile"
        ];
        postBunSetInstallCacheDirPhase = ''
          chmod -R u+w "$BUN_INSTALL_CACHE_DIR"
        '';
      })
    else packageWithFixedBunDeps;
in {
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
      pkgs-unstable.gws # Google Workspace CLI; only in unstable
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

      inputs.llm-agents.packages.${pkgs.system}.agentsview
      inputs.llm-agents.packages.${pkgs.system}.claude-code
      inputs.llm-agents.packages.${pkgs.system}.codex
      inputs.llm-agents.packages.${pkgs.system}.herdr
      inputs.llm-agents.packages.${pkgs.system}.hunk
      inputs.llm-agents.packages.${pkgs.system}.omp
      inputs.llm-agents.packages.${pkgs.system}.opencode
      # pi is installed (wrapped) from modules/programs/agents/pi.nix
      inputs.llm-agents.packages.${pkgs.system}.qmd
      inputs.llm-agents.packages.${pkgs.system}.rtk
      inputs.llm-agents.packages.${pkgs.system}.tuicr
      inputs.wiggle-puppy.packages.${pkgs.system}.default
      (pkgs.callPackage ./ralph {})
      (pkgs.callPackage ./td {}) # task tracking for AI coding sessions
    ]
    ++ builtins.map garageCli garageCliNames
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
