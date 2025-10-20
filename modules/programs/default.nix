{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./browsers
    ./claude-code
    ./nvf
    ./common.nix
    ./ghostty.nix
    ./git.nix
    ./media.nix
    ./plasma.nix
    ./shell.nix
    ./ssh.nix
    ./syncthing.nix
  ];
}
