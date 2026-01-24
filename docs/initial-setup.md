# Initial Setup on New Machines

## SSH Key Setup

SSH keys are stored in your password manager and need to be retrieved on new machines.

1. **Retrieve your SSH key from password manager**:
   - Find your SSH key entry
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

## Age Key Setup (for sops-nix secrets)

The age key is used to decrypt secrets managed by sops-nix.

1. **Copy your age key from an existing machine**:
   ```bash
   # From existing machine
   scp ~/.config/sops/age/keys.txt user@newmachine:.config/sops/age/keys.txt
   ```

   Or manually:
   ```bash
   mkdir -p ~/.config/sops/age
   chmod 700 ~/.config/sops/age

   # Paste the key content, then press Ctrl+D
   cat > ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```

2. **Verify it works**:
   ```bash
   cd ~/nixos-config
   nix develop
   sops secrets/framework13.yaml  # should open decrypted
   ```

Note: The age key is stored in your password manager alongside SSH keys.
Without it, you cannot edit or decrypt secrets.
