{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.vaults;
  localVault =
    if cfg.profile == "work"
    then "flosports"
    else "private";
in {
  options.vaults = {
    deviceName = lib.mkOption {
      type = lib.types.str;
      description = "Device name in the shared Syncthing registry.";
    };
    profile = lib.mkOption {
      type = lib.types.enum ["work" "personal"];
      description = "Select work or personal vaults for this device.";
    };
    capturePath = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Default destination for notes that have not been reviewed for sharing.";
    };
  };

  config = {
    vaults.capturePath = "${config.home.homeDirectory}/vaults/${localVault}";
    home.sessionVariables.OBSIDIAN_VAULT_PATH = cfg.capturePath;

    home.activation.vaultDirectories = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p "$HOME/vaults/brain" ${lib.escapeShellArg cfg.capturePath}
    '';

    home.file = lib.genAttrs (map (name: "vaults/${name}/.stignore") ["brain" localVault]) (_: {
      text = ''
        /.obsidian
        /.git
        /.trash
        /.claude/settings.local.json
        (?d).DS_Store
      '';
    });

    home.activation.syncthingLogDirectory = lib.mkIf pkgs.stdenv.isDarwin (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p "$HOME/Library/Logs/Syncthing"
      ''
    );
  };
}
