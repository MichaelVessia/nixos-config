{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  defaultMode = lib.importJSON ./default-mode.json;
  modes = lib.importJSON ./modes.json;
  macHex = "/Applications/Hex.app/Contents/MacOS/hex";
in {
  imports = [inputs.hex.homeManagerModules.hex];

  config = lib.mkMerge [
    {
      # Hex rejects symlinks that point outside its configuration directory.
      home.activation.hexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${pkgs.coreutils}/bin/install -D -m 0644 \
          ${./hex.config.ts} \
          ${lib.escapeShellArg "${config.xdg.configHome}/hex/hex.config.ts"}
        run ${pkgs.coreutils}/bin/install -D -m 0644 \
          ${./transformations.ts} \
          ${lib.escapeShellArg "${config.xdg.configHome}/hex/transformations.ts"}
      '';
    }

    # flomac installs Hex from the Homebrew cask.
    (lib.mkIf pkgs.stdenv.isDarwin {
      # Use Hex's live API; never overwrite settings.json while Hex runs.
      home.activation.hexMacSettings = lib.hm.dag.entryAfter ["hexConfig"] ''
        if [ -x ${macHex} ] && ${macHex} status --json >/dev/null 2>&1; then
          run ${macHex} settings set dictation_processing.default_mode \
            ${lib.escapeShellArg (builtins.toJSON defaultMode)}
          run ${macHex} settings set dictation_processing.modes \
            ${lib.escapeShellArg (builtins.toJSON modes)}
        fi
      '';
    })

    (lib.mkIf pkgs.stdenv.isLinux {
      programs.hex = {
        enable = true;
        autostart = true;
        settings = {
          "dictation_processing.default_mode" = defaultMode;
          "dictation_processing.modes" = modes;
        };
      };
    })
  ];
}
