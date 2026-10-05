{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "namespace-devbox";
  version = "0.0.196";

  src = fetchurl {
    url = "https://get.namespace.so/packages/devbox/v${version}/devbox_${version}_darwin_arm64.tar.gz";
    sha256 = "865ff1f64fb33d6773e00f23cc941f15e67d8a6797438c00ff9b8e0aa9632db2";
  };

  sourceRoot = ".";
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 devbox $out/bin/namespace-devbox
    runHook postInstall
  '';

  meta = {
    description = "Namespace Devbox CLI (separate from Jetify Devbox)";
    homepage = "https://namespace.so/docs/devbox";
    license = lib.licenses.unfree;
    platforms = ["aarch64-darwin"];
    mainProgram = "namespace-devbox";
  };
}
