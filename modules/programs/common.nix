{
  config,
  pkgs,
  inputs,
  ...
}: {
  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    neofetch
    yazi

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    fd # find replacement
    ncdu # disk usage
    curl
    wget
    git-town
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

    # productivity
    glow # markdown previewer in terminal
    bitwarden # password manager
    signal-desktop # secure messaging

    # terminal emulators
    ghostty

    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    inputs.claude-code.packages.${pkgs.system}.default
  ];
}
