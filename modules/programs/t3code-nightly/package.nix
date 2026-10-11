{
  lib,
  appimageTools,
  fetchurl,
  providerPackages,
}: let
  pname = "t3code-desktop";
  version = "0.0.46-nightly.20261011.2980";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    hash = "sha256-nYbs9Mv5e1x97860vn9erTKyTxGxeba/jN6Eihr0Mz4=";
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
      install -Dm444 ${contents}/t3code.desktop $out/share/applications/t3code.desktop
      substituteInPlace $out/share/applications/t3code.desktop \
        --replace-fail 'Exec=AppRun %U' 'Exec=${pname} %U'
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
