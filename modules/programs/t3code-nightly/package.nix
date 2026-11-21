{
  lib,
  appimageTools,
  fetchurl,
  providerPackages,
}: let
  pname = "t3code-desktop";
  version = "0.1.12-nightly.20261121.5024";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-Nightly-x86_64.AppImage";
    hash = "sha256-UjOU+juT8Og3Z4Ugiu+EX4O7td8IkIYln+CPz8G7cX4=";
  };
  contents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
  appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs = pkgs: [pkgs.util-linux];
    profile = ''
      export PATH=${lib.makeBinPath providerPackages}:"$PATH"
      export T3CODE_DISABLE_AUTO_UPDATE=true
    '';
    extraInstallCommands = ''
      desktop_file="$(find ${contents} -maxdepth 1 -name '*.desktop' | head -n 1)"
      install -Dm444 "$desktop_file" $out/share/applications/t3code.desktop
      substituteInPlace $out/share/applications/t3code.desktop \
        --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      cp -r ${contents}/usr/share/icons $out/share/
    '';
    meta = {
      description = "Nightly desktop control surface for coding agents";
      homepage = "https://t3.codes";
      changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      license = lib.licenses.mit;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      mainProgram = pname;
      platforms = ["x86_64-linux"];
    };
  }
