---
description: Set up Nix flake with bun + typescript devShell
---

# Initialize Nix Flake

Set up a Nix flake with bun and typescript for development.

## Steps

1. **Check for existing flake.nix** - ask before overwriting

2. **Get project name** from directory name or package.json if exists

3. **Create `flake.nix`**:
   ```nix
   {
     description = "<project-name>";

     inputs = {
       nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
     };

     outputs = {nixpkgs, ...}: let
       forAllSystems = function:
         nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed
         (system: function nixpkgs.legacyPackages.${system});
     in {
       formatter = forAllSystems (pkgs: pkgs.alejandra);
       devShells = forAllSystems (pkgs: {
         default = pkgs.mkShell {
           packages = with pkgs; [
             bun
             typescript
             lefthook
           ];
         };
       });
     };
   }
   ```

4. **Create `.envrc`** (if not exists):
   ```
   use flake
   ```

5. **Add to `.gitignore`** (if not present):
   ```
   .direnv/
   result
   ```

6. **Run `direnv allow`** if direnv is available

7. **Summary**: Created files, remind to run `nix develop` or let direnv activate

## Notes

- This creates a minimal devShell; add more packages as needed
- For projects needing nix packaging (bun2nix), that's a separate enhancement
- lefthook included by default for git hooks support
