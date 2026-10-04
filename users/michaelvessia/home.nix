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

  # Preserve existing shares until this device can be inventoried.
  services.syncthing.overrideDevices = false;
  services.syncthing.overrideFolders = false;

  vaults = {
    deviceName = "framework13";
    profile = "personal";
  };

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";
}
