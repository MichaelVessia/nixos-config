---
description: Add bun2nix packaging to an existing flake
---

# Add Nix Packaging to Flake

Convert a devShell-only flake to a deployable package using bun2nix.

## Prerequisites

- Existing `flake.nix` with devShell
- `bun.lock` file (run `bun install` first)
- Entry point file (e.g., `src/main.ts` or `src/index.ts`)

## Steps

1. **Detect project info**:
   - pname/version from package.json
   - Entry point: check for `src/main.ts`, `src/index.ts`, or ask

2. **Generate `bun.nix`**:
   ```bash
   nix run github:nix-community/bun2nix
   ```

3. **Replace `flake.nix`** with packaging version:
   ```nix
   {
     description = "<project-name>";

     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
       flake-utils.url = "github:numtide/flake-utils";
       bun2nix = {
         url = "github:nix-community/bun2nix";
         inputs.nixpkgs.follows = "nixpkgs";
       };
     };

     outputs = {
       self,
       nixpkgs,
       flake-utils,
       bun2nix,
     }:
       flake-utils.lib.eachDefaultSystem (system: let
         pkgs = nixpkgs.legacyPackages.${system};
         bun2nix' = bun2nix.packages.${system}.default;
       in {
         packages.default = pkgs.stdenv.mkDerivation {
           pname = "<pname>";
           version = "<version>";
           src = ./.;

           nativeBuildInputs = [
             bun2nix'.hook
             pkgs.makeBinaryWrapper
           ];

           bunDeps = bun2nix'.fetchBunDeps {
             bunNix = ./bun.nix;
           };

           # Run with bun interpreter (not AOT compiled)
           dontUseBunBuild = true;
           dontUseBunCheck = true;
           dontUseBunInstall = true;

           installPhase = ''
             runHook preInstall

             mkdir -p $out/lib/<pname>
             cp -r . $out/lib/<pname>

             mkdir -p $out/bin
             makeBinaryWrapper ${pkgs.bun}/bin/bun $out/bin/<pname> \
               --add-flags "run $out/lib/<pname>/<entry-point>"

             runHook postInstall
           '';
         };

         devShells.default = pkgs.mkShell {
           buildInputs = with pkgs; [
             bun
             typescript
             lefthook
             bun2nix'
           ];

           shellHook = ''
             echo "<project-name> dev shell"
             echo "  bun2nix - Regenerate bun.nix after lockfile changes"
           '';
         };
       });
   }
   ```

4. **Add to `.gitignore`** (if not present):
   ```
   result
   ```

5. **Test the build**:
   ```bash
   nix build
   ./result/bin/<pname>
   ```

6. **Summary**: Note that `bun2nix` must be re-run after lockfile changes

## Notes

- Uses bun interpreter at runtime (not AOT compilation) for better compatibility
- Add extra packages to devShell as needed
- For monorepos, adjust entry point path accordingly
