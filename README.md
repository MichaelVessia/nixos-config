# NixOS Configuration

Personal NixOS configuration with Home Manager.

## Initial Setup on New Machines

### SSH Key Setup

SSH keys are stored in Bitwarden and need to be retrieved on new machines.

1. **Retrieve your SSH key from Bitwarden**:
   - Open Bitwarden and find your SSH key entry
   - Copy the private key (starts with `-----BEGIN OPENSSH PRIVATE KEY-----`)
   - Copy the public key (starts with `ssh-ed25519`)

2. **Save the keys to the correct location**:
   ```bash
   # Create .ssh directory with correct permissions
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh

   # Save the private key
   # Paste the private key content, then press Ctrl+D
   cat > ~/.ssh/id_ed25519
   chmod 600 ~/.ssh/id_ed25519

   # Save the public key
   # Paste the public key content, then press Ctrl+D
   cat > ~/.ssh/id_ed25519.pub
   chmod 644 ~/.ssh/id_ed25519.pub
   ```

3. **Verify the key is set up correctly**:
   ```bash
   ssh -T git@github.com
   # Should see: "Hi <username>! You've successfully authenticated..."
   ```

Note: The public key should already be added to GitHub. If setting up a
completely new key, add it at https://github.com/settings/keys

### Applying Configuration

```bash
# System rebuild
sudo nixos-rebuild switch

# Or use the alias
nrs
```

## Directory Structure

- `modules/` - Modular configuration files
  - `programs/` - Application and service configurations
- `users/` - User-specific configurations
- `hosts/` - Host-specific configurations
