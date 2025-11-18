{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
  ];

  home.username = "michael.vessia";
  home.homeDirectory = "/Users/michael.vessia";
}
