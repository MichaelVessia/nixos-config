{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
    ../../modules/secrets/flomac.nix
  ];

  home.username = "michael.vessia";
  home.homeDirectory = "/Users/michael.vessia";
}
