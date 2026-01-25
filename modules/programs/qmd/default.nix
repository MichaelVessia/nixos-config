# qmd - local semantic search for docs/notes
#
# Packaged locally using bun2nix since upstream flake
# tries to fetch deps at build time (incompatible with Nix sandbox).
#
# To update:
#   1. Update rev/hash below to latest commit
#   2. Clone repo, run: nix run github:nix-community/bun2nix > bun.nix
{
  pkgs,
  lib,
  bun2nix,
  ...
}: let
  bun2nix' = bun2nix.packages.${pkgs.system}.default;

  qmdSrc = pkgs.fetchFromGitHub {
    owner = "tobi";
    repo = "qmd";
    rev = "88f78314bb22bd23e68bf4d16a447323c2a29b0f";
    hash = "sha256-ejJxsUW1KlUobNvweU0cCx224dvAb1jQUfGLrYeSNM8=";
  };

  # Runtime libs for node-llama-cpp prebuilt binaries
  runtimeLibs = [
    pkgs.sqlite
    pkgs.stdenv.cc.cc.lib
    pkgs.glibc # for glibc detection by node-llama-cpp
  ];

  qmd = pkgs.stdenv.mkDerivation {
    pname = "qmd";
    version = "1.0.0";
    src = qmdSrc;

    nativeBuildInputs = [
      bun2nix'.hook
      pkgs.makeBinaryWrapper
      pkgs.autoPatchelfHook
    ];

    # Ignore CUDA/Vulkan/musl deps - we only need CPU support
    autoPatchelfIgnoreMissingDeps = [
      "libcudart.so.*"
      "libcublas.so.*"
      "libcuda.so.*"
      "libvulkan.so.*"
      "libc.musl-x86_64.so.*"
    ];

    bunDeps = bun2nix'.fetchBunDeps {
      bunNix = ./bun.nix;
    };

    # Skip bun's default phases
    dontUseBunBuild = true;
    dontUseBunCheck = true;
    dontUseBunInstall = true;

    buildInputs = runtimeLibs;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/qmd $out/bin
      cp -r . $out/lib/qmd
      cp -r node_modules $out/lib/qmd/

      makeBinaryWrapper ${pkgs.bun}/bin/bun $out/bin/qmd \
        --add-flags "run" \
        --add-flags "$out/lib/qmd/src/qmd.ts" \
        --set-default LD_LIBRARY_PATH "${lib.makeLibraryPath runtimeLibs}" \
        --set-default DYLD_LIBRARY_PATH "${lib.makeLibraryPath [pkgs.sqlite]}"

      runHook postInstall
    '';
  };
in {
  home.packages = [qmd];
}
