{
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs/agents
    ../../modules/programs/nvf
    ../../modules/programs/git.nix
    ../../modules/programs/shell.nix
    ../../modules/programs/zellij.nix
    ../../modules/programs/ssh.nix
    ../../modules/programs/vaults.nix
    ../../modules/programs/t3.nix
    ../../modules/programs/worktrunk.nix
  ];

  # Agents write notes to a local work vault. Syncthing does not run here, so
  # the notes stay on this machine.
  vaults = {
    deviceName = "dev-machine";
    profile = "work";
  };

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";

  # Keep the headless profile independent of common.nix's desktop packages.
  home.packages = with pkgs; [
    bun
    nodejs
    python3
    gcc
    gnumake
    pkg-config
    ripgrep
    ast-grep
    jq
    yq-go
    fd
    curl
    wget
    zip
    unzip
    file
    tree
    tmux
    btop
    ncdu
    difftastic
    lazygit
    lsof
    nix-output-monitor
    pkgs-unstable.devbox
    devenv
    lefthook
    inputs.llm-agents.packages.${pkgs.system}.claude-code
    inputs.llm-agents.packages.${pkgs.system}.omp
    inputs.llm-agents.packages.${pkgs.system}.herdr
    inputs.llm-agents.packages.${pkgs.system}.hunk
  ];
}
