{
  pkgs,
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
    ../../modules/programs/syncthing.nix
    ../../modules/programs/worktrunk.nix
  ];

  vaults = {
    deviceName = "foundry";
    profile = "work";
  };

  home.username = "foundry";
  home.homeDirectory = "/home/foundry";

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
    cloudflared
    nix-output-monitor
    devbox
    devenv
    lefthook
    sops
    age
    ssh-to-age
    inputs.llm-agents.packages.${pkgs.system}.claude-code
    inputs.llm-agents.packages.${pkgs.system}.omp
    inputs.llm-agents.packages.${pkgs.system}.herdr
    inputs.llm-agents.packages.${pkgs.system}.hunk
  ];
}
