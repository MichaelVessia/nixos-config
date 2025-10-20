{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./browsers
    ./nvf
    ./common.nix
    ./ghostty.nix
    ./git.nix
    ./plasma.nix
    ./shell.nix
    ./ssh.nix
    ./syncthing.nix
  ];
}
