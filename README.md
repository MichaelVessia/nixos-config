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
  - `secrets/` - sops-nix secret declarations per host
- `users/` - User-specific configurations
- `hosts/` - Host-specific configurations
- `secrets/` - Encrypted secret files (safe to commit)
- `scripts/` - Helper scripts (pre-commit hooks, etc.)

## Secrets Management

Uses [sops-nix](https://github.com/Mic92/sops-nix) with age encryption.

### Setup (new machine)

1. Copy your age key:
   ```bash
   # From existing machine
   scp ~/.config/sops/age/keys.txt user@newmachine:.config/sops/age/keys.txt
   ```

2. Enter devShell for tools:
   ```bash
   nix develop
   ```

### Adding a new secret

1. Edit the encrypted secrets file:
   ```bash
   sops secrets/framework13.yaml  # or flomac.yaml, tts-pi.yaml
   ```

2. Add your secret in YAML format:
   ```yaml
   my_new_secret: "the secret value"
   ```

3. Declare the secret in the corresponding module (`modules/secrets/*.nix`):
   ```nix
   sops.secrets.my_new_secret = {};
   ```

4. Rebuild:
   ```bash
   reload  # or nixos-rebuild/darwin-rebuild
   ```

### Using secrets

Secrets are decrypted at activation time:

| Platform | Location |
|----------|----------|
| NixOS | `/run/secrets/<name>` |
| macOS | `~/.config/sops-nix/secrets/<name>` |

**In shell (env var):**
```nix
programs.zsh.initExtra = ''
  export MY_SECRET="$(cat ${config.sops.secrets.my_new_secret.path} 2>/dev/null)"
'';
```

**In systemd service:**
```nix
systemd.services.myservice.serviceConfig = {
  EnvironmentFile = config.sops.secrets.my_new_secret.path;
};
```

### Secret files per host

| File | Host | Can decrypt |
|------|------|-------------|
| `secrets/framework13.yaml` | framework13 | You (personal key) |
| `secrets/flomac.yaml` | flomac | You (personal key) |
| `secrets/tts-pi.yaml` | tts-pi | You + Pi (host key) |
| `secrets/common.yaml` | All | You + Pi |

### Adding a new host

1. Get the host's age key (from SSH host key):
   ```bash
   ssh user@host 'cat /etc/ssh/ssh_host_ed25519_key.pub' | ssh-to-age
   ```

2. Add the key to `.sops.yaml` under `keys:`

3. Add a creation rule for the host's secrets file

4. Create `modules/secrets/<host>.nix` with sops config

### Pre-commit hook

Lefthook prevents committing unencrypted secrets. Install hooks:
```bash
nix develop  # auto-installs via shellHook
# or manually: lefthook install
```
