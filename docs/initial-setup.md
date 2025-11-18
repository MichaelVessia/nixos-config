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
