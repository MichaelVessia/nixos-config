{
  lib,
  pkgs,
  ...
}: let
  # Upstream ships prebuilt single-file binaries on GitHub releases (no Nix
  # package in llm-agents.nix). Pin a release and fetch the per-system asset;
  # the @plannotator/pi-extension (see pi.nix) shells out to this `plannotator`
  # binary, so it needs to be on PATH.
  version = "0.20.1";

  plat =
    {
      aarch64-darwin = {
        asset = "plannotator-darwin-arm64";
        hash = "sha256-OepCxo081rev9QkFosBzCDqdn8gKPD4fBp6fxwzF+3c=";
      };
      x86_64-linux = {
        asset = "plannotator-linux-x64";
        hash = "sha256-CZ9bDrW8bsQN6WposE4TBr6l88uw98lUtp/Z5nWEOgU=";
      };
    }
    .${
      pkgs.system
    }
      or (throw "plannotator: unsupported system ${pkgs.system}");

  plannotator = pkgs.stdenvNoCC.mkDerivation {
    pname = "plannotator";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/${plat.asset}";
      inherit (plat) hash;
    };

    dontUnpack = true;

    # The Linux build is a dynamically-linked ELF; patch its interpreter and
    # rpath. Darwin runs the Mach-O binary as-is.
    nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.autoPatchelfHook];
    buildInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.stdenv.cc.cc.lib];

    installPhase = ''
      runHook preInstall
      install -Dm755 $src $out/bin/plannotator
      runHook postInstall
    '';

    meta = {
      description = "Browser-based review tool for AI coding agents";
      homepage = "https://github.com/backnotprop/plannotator";
      platforms = ["aarch64-darwin" "x86_64-linux"];
      mainProgram = "plannotator";
    };
  };
in {
  config.home.packages = [plannotator];
}
