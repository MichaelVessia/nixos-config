{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [
    ./browsers
    ./agents
    ./nvf
    ./common.nix
    ./cmux.nix
    ./ghostty.nix
    ./git.nix
    ./media.nix
    ./shell.nix
    ./zellij.nix
    ./ssh.nix
    ./syncthing.nix
    ./transcribe.nix
    ./worktrunk.nix
    ./x-to-obsidian.nix
    ./basalt.nix
    ./fmcal.nix
    ./floai.nix
    ./paperless-cli.nix
    ./hass-cli.nix
    ./kuma-cli.nix
    ./subq.nix
    ./takopi
    ./karabiner.nix
    ./hammerspoon.nix
    ./raycast.nix
    # ./zed.nix  # disabled - takes too long to build from source
  ];
}
