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

    (lib.mkIf pkgs.stdenv.isLinux (let
      # Hex's oxc crates need rustc 1.97; stable nixpkgs defaults to 1.95.
      hexPackage = inputs.hex.packages.${pkgs.stdenv.hostPlatform.system}.hex.override {
        inherit (pkgs.rustPackages_1_97) rustPlatform;
      };
      hexHotkeyd = pkgs.writeShellApplication {
        name = "hex-hotkeyd";
        text = ''
          exec ${pkgs.python3.withPackages (ps: [ps.evdev])}/bin/python3 ${./hex_hotkeyd.py} "$@"
        '';
      };
    in {
      programs.hex = {
        enable = true;
        package = hexPackage;
        autostart = true;
        settings = {
          "dictation_processing.default_mode" = defaultMode;
          "dictation_processing.modes" = modes;
          "labs.unload_idle" = true;
        };
      };

      systemd.user.services.hex-hotkeyd = {
        Unit = {
          Description = "Hex evdev hold and double-tap hotkey daemon";
          After = ["graphical-session.target" "hex.service"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          Type = "simple";
          Environment = ["HEX_APPLICATION_SUPPORT_DIR=${config.xdg.dataHome}/hex"];
          ExecStart = "${hexHotkeyd}/bin/hex-hotkeyd --hex-bin ${hexPackage}/bin/hex";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    }))
  ];
}
