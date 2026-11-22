{
  fetchurl,
  gnutar,
  gzip,
  lib,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}: let
  version = "2.0.0-beta.66";
in
  stdenvNoCC.mkDerivation {
    pname = "executor";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/executor/-/executor-${version}.tgz";
      hash = "sha512-J/zcjsY/L4oJ0eh+VgnsfS4nwMaXLPU7BKy0XdC2+5sI+wBf9f32ZGA8GsSn40hkMFt9JF2xQDn2NAhRtZS0PQ==";
    };

    sourceRoot = "package";
    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/executor"
      cp -r . "$out/share/executor/"
      makeWrapper ${nodejs}/bin/node "$out/bin/executor" \
        --add-flags "$out/share/executor/bin.mjs" \
        --prefix PATH : ${lib.makeBinPath [gnutar gzip]}
      runHook postInstall
    '';

    meta = {
      homepage = "https://executor.sh";
      mainProgram = "executor";
      platforms = ["x86_64-linux"];
    };
  }
