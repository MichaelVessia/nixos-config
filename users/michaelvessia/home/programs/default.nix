{ config, pkgs, inputs, ... }:

{
  imports = [
    ./git.nix
    ./shell.nix
    ./common.nix
    ./browsers.nix
    ./ghostty.nix
  ];
}
