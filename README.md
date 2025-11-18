# NixOS Configuration

Personal NixOS configuration with Home Manager.

## Initial Setup

See [docs/initial-setup.md](docs/initial-setup.md) for SSH key setup and first-time configuration.

## Applying Configuration

Platform-agnostic rebuild (works on both NixOS and macOS):
```bash
reload
```

Or manually:
```bash
# NixOS
sudo nixos-rebuild switch --flake .#framework13

# macOS (nix-darwin)
sudo darwin-rebuild switch --flake .#flomac
```

## Directory Structure

- `modules/` - Modular configuration files
  - `programs/` - Application and service configurations
- `users/` - User-specific configurations
- `hosts/` - Host-specific configurations
