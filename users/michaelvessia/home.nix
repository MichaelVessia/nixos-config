{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
    ../../modules/programs/niri.nix
  ];

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";
}
