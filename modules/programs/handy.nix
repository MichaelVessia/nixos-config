# Handy speech-to-text for Linux
# Runs the extracted AppImage via nix-ld
{
  config,
  lib,
  pkgs,
  ...
}: let
  handyDir = "${config.home.homeDirectory}/.local/share/handy";
  handyBin = "${handyDir}/usr/bin/handy";

  # Wrapper script that runs the extracted AppImage
  handyWrapper = pkgs.writeShellScriptBin "handy" ''
    if [[ ! -x "${handyBin}" ]]; then
      echo "Handy not found at ${handyBin}"
      exit 1
    fi
    exec "${handyBin}" "$@"
  '';
in
  lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [handyWrapper];

    # Desktop entry for app launcher
    xdg.desktopEntries.handy = {
      name = "Handy";
      comment = "Speech-to-text transcription";
      exec = "${handyWrapper}/bin/handy";
      icon = "${handyDir}/handy.png";
      terminal = false;
      categories = ["Utility" "Accessibility"];
    };

    # Autostart on login
    xdg.configFile."autostart/handy.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Handy
      Comment=Speech-to-text transcription
      Exec=${handyWrapper}/bin/handy
      Icon=${handyDir}/handy.png
      Terminal=false
      Categories=Utility;Accessibility;
      X-GNOME-Autostart-enabled=true
    '';
  }
