{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs/claude-code
    ../../modules/programs/nvf
    ../../modules/programs/common.nix
    ../../modules/programs/git.nix
    ../../modules/programs/shell.nix
    ../../modules/programs/zellij.nix
    ../../modules/programs/ssh.nix
    ../../modules/programs/qmd
    ../../modules/programs/basalt.nix
  ];

  home.username = "cc";
  home.homeDirectory = "/home/cc";
}
