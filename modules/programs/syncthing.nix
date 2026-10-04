{
  lib,
  config,
  ...
}: let
  cfg = config.vaults;
  devices = import ./vault-devices.nix;
  peers = lib.filterAttrs (name: _: name != cfg.deviceName) devices;
  localVault =
    if cfg.profile == "work"
    then "flosports"
    else "private";
  folder = name: members: {
    id = "obsidian-${name}";
    path = "${config.home.homeDirectory}/vaults/${name}";
    devices = lib.attrNames members;
    type = "sendreceive";
    ignorePerms = true;
    versioning = {
      type = "staggered";
      params.maxAge = "7776000";
    };
  };
in {
  assertions = [
    {
      assertion = !(devices ? ${cfg.deviceName}) || devices.${cfg.deviceName}.profile == cfg.profile;
      message = "The vault profile must match vault-devices.nix.";
    }
  ];

  services.syncthing = {
    enable = true;
    tray.enable = false;
    settings = {
      devices =
        lib.mapAttrs (_: device: {
          inherit (device) id;
          addresses = lib.optional (device ? address) device.address ++ ["dynamic"];
          autoAcceptFolders = false;
          introducer = false;
        })
        peers;
      folders = {
        brain = folder "brain" peers;
        ${localVault} = folder localVault (lib.filterAttrs (_: device: device.profile == cfg.profile) peers);
      };
    };
  };
}
