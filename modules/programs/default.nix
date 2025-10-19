{ config, pkgs, inputs, ... }:

{
  imports = [
    ./browsers
    ./editors
    ./common.nix
    ./ghostty.nix
    ./git.nix
    ./plasma.nix
    ./shell.nix
  ];
}
