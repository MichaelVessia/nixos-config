# OpenWhispr - privacy-first voice dictation, meeting transcription & notes
# https://github.com/OpenWhispr/openwhispr
#
# Upstream's flake only packages x86_64-linux (an AppImage wrapper), so on
# Linux we consume it via the openwhispr flake input. On darwin we fetch the
# release dmg (arm64 only, matching flomac) and install the app bundle.
{
  lib,
  pkgs,
  inputs,
  ...
}: let
  version = "1.7.2";
  darwinApp = pkgs.stdenvNoCC.mkDerivation {
    pname = "openwhispr";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/OpenWhispr/openwhispr/releases/download/v${version}/OpenWhispr-${version}-arm64.dmg";
      hash = "sha256-llwuu5xiUxQJqluH4x9sa4rthNMoXx9z7VupbR37uzE=";
    };

    nativeBuildInputs = [pkgs.undmg];
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications
      cp -R *.app $out/Applications/
      runHook postInstall
    '';

    meta = {
      description = "Privacy-first desktop voice dictation, meeting transcription & notes";
      homepage = "https://openwhispr.com/";
      license = lib.licenses.mit;
      platforms = ["aarch64-darwin"];
    };
  };
  system = pkgs.stdenv.hostPlatform.system;
in {
  home.packages =
    if pkgs.stdenv.isDarwin
    then [darwinApp]
    else lib.optional (system == "x86_64-linux") inputs.openwhispr.packages.${system}.default;
}
