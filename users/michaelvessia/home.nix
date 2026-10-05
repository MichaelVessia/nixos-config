{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  osConfig,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
    ../../modules/programs/niri.nix
  ];

  home.packages = [
    inputs.grok-bot.packages.${pkgs.system}.default
    inputs.llm-agents.packages.${pkgs.system}.t3code-desktop
  ];

  # Preserve existing shares until this device can be inventoried.
  services.syncthing.overrideDevices = false;
  services.syncthing.overrideFolders = false;

  vaults = {
    deviceName = osConfig.networking.hostName;
    profile = "personal";
  };

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";
}
