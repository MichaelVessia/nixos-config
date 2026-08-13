{
  config,
  lib,
  pkgs,
  ...
}: let
  snapshotDir = ./config;
  homeDir = config.home.homeDirectory;
  dmsConfigDir = "${homeDir}/.config/DankMaterialShell";
  dmsCacheDir = "${homeDir}/.cache/DankMaterialShell";
  niriDmsDir = "${homeDir}/.config/niri/dms";

  dmsConfigSave = pkgs.writeShellApplication {
    name = "dms-config-save";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail

      repo="''${NIXOS_CONFIG_REPO:-$HOME/nixos-config}"
      repo_snapshot="$repo/modules/programs/dms/config"
      mkdir -p "$repo_snapshot/niri"

      cp "${dmsConfigDir}/settings.json" "$repo_snapshot/settings.json"
      cp "${dmsCacheDir}/dms-colors.json" "$repo_snapshot/dms-colors.json"
      cp "${niriDmsDir}"/*.kdl "$repo_snapshot/niri/"

      printf 'Saved DMS config snapshot to %s\n' "$repo_snapshot"
    '';
  };

  dmsConfigRestore = pkgs.writeShellApplication {
    name = "dms-config-restore";
    runtimeInputs = [pkgs.coreutils pkgs.niri];
    text = ''
      set -euo pipefail

      repo="''${NIXOS_CONFIG_REPO:-$HOME/nixos-config}"
      repo_snapshot="$repo/modules/programs/dms/config"
      if [ ! -d "$repo_snapshot" ]; then
        repo_snapshot="${toString snapshotDir}"
      fi

      mkdir -p "${dmsConfigDir}" "${dmsCacheDir}" "${niriDmsDir}"

      cp "$repo_snapshot/settings.json" "${dmsConfigDir}/settings.json"
      cp "$repo_snapshot/dms-colors.json" "${dmsCacheDir}/dms-colors.json"
      cp "$repo_snapshot/niri/"*.kdl "${niriDmsDir}/"

      if niri msg action load-config-file >/dev/null 2>&1; then
        printf 'Restored DMS config snapshot and reloaded niri\n'
      else
        printf 'Restored DMS config snapshot. Restart DMS or niri to apply all changes.\n'
      fi
    '';
  };
in
  lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      dmsConfigSave
      dmsConfigRestore
    ];

    home.activation.seedDmsConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p "${dmsConfigDir}" "${dmsCacheDir}" "${niriDmsDir}"

      if [ ! -e "${dmsConfigDir}/settings.json" ]; then
        $DRY_RUN_CMD cp "${snapshotDir}/settings.json" "${dmsConfigDir}/settings.json"
      fi

      if [ ! -e "${dmsCacheDir}/dms-colors.json" ]; then
        $DRY_RUN_CMD cp "${snapshotDir}/dms-colors.json" "${dmsCacheDir}/dms-colors.json"
      fi

      for source in "${snapshotDir}/niri/"*.kdl; do
        target="${niriDmsDir}/$(basename "$source")"
        if [ ! -e "$target" ]; then
          $DRY_RUN_CMD cp "$source" "$target"
        fi
      done
    '';
  }
