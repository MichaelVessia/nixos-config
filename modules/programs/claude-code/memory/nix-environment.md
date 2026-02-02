# Nix Environment Patterns

## Flake Setup

When environment fails, add or update `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = [ /* deps here */ ];
        };
      });
}
```

## Key Rules

- Expose `devShells.default` for `nix develop`
- Do NOT run nix commands that change environment (unless user says OK)
- For one-off missing programs: `nix run nixpkgs#<package>`

## Common Patterns

### Adding Build Dependencies

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    nodejs
    nodePackages.typescript
    nodePackages.pnpm
  ];
};
```

### With Shell Hook

```nix
devShells.default = pkgs.mkShell {
  packages = [ ... ];
  shellHook = ''
    echo "Dev environment ready"
  '';
};
```

## NixOS Module vs Home Manager

- System services: `/etc/nixos/configuration.nix` or host-specific `default.nix`
- User programs: home-manager modules under `modules/programs/`
- Secrets: use sops-nix, not plain text in nix files

## Debugging

- `nix flake check` to validate
- `nix flake show` to see outputs
- `nix develop --command $SHELL` for debugging shell setup
