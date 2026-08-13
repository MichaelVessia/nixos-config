{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs/agents
    ../../modules/programs/nvf
    ../../modules/programs/common.nix
    ../../modules/programs/git.nix
    ../../modules/programs/shell.nix
    ../../modules/programs/zellij.nix
    ../../modules/programs/ssh.nix
    ../../modules/programs/takopi
  ];

  home.username = "cc";
  home.homeDirectory = "/home/cc";
}
