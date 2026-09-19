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

  home.packages = [
    inputs.grok-bot.packages.${pkgs.system}.default
  ];

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";
}
