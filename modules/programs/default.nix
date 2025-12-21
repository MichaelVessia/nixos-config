{
  config,
  pkgs,
  pkgs-unstable,
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
    ./shell.nix
    ./shout.nix
    ./ssh.nix
    ./syncthing.nix
    ./transcribe.nix
    # ./zed.nix  # disabled - takes too long to build from source
  ];
}
