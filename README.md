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

# macOS (nix-darwin; flomac deployment entry point)
sudo darwin-rebuild switch --flake ./hosts/flomac#flomac
```

Both the root flake and `hosts/flomac/flake.nix` include the private `floai`
input. Updating it requires GitHub SSH authentication and flocasts SAML access.
The flomac deployment entry point uses its own `hosts/flomac/flake.lock`.

### Foundry headless devbox

`foundry` is an x86_64 NixOS devbox with the login user `foundry`, no desktop,
and a Btrfs SSD. Its installer-generated mounts are preserved in
`hosts/foundry/hardware-configuration.nix`; regenerate that file on the machine
if the disk layout changes. The headless Home Manager profile in
`users/foundry/home.nix` reuses the shell, Git, Neovim, Zellij, Worktrunk, and
agent modules without importing the desktop package collection.

Keep the repository at `/home/foundry/nixos-config`: agent settings use writable
links into that checkout. Agent OAuth credentials and private GitHub access
must be authorized separately; no private credentials are copied automatically.
SSH accepts the configured Framework and Mac public keys; password and root
SSH logins are disabled. Sudo still requires the user's password. The `foundry`
user is trusted by Nix, like the existing dev host's admin user.

Foundry includes the Google Cloud CLI. After rebuilding, sign in as the
`foundry` user on Foundry with `gcloud auth login --no-launch-browser`.
Follow the printed URL in your browser and enter the authorization code in
that terminal. Agents on Foundry can then use this login. For Cloud Build
checks, pass `--project=flosports-174016`; the account needs permission to
read the build and its logs. Credentials remain outside this repository.

Foundry joins the tailnet; the shared SSH module defines `ssh foundry` as
`foundry@foundry` through MagicDNS. Rebuild the client machine to activate the
shortcut. The `foundry` user is a Tailscale operator and lingers, so the T3
Code user service can publish itself with Tailscale Serve.

Build from an existing authenticated x86_64 machine:

```bash
nix build .#nixosConfigurations.foundry.config.system.build.toplevel --no-link
```

After the first deployment, remote updates can be built here without putting
private GitHub credentials on the devbox:

```bash
nixos-rebuild switch --flake .#foundry \
  --target-host foundry@foundry --ask-sudo-password
```

The initial stock installation does not yet trust the `foundry` Nix user, so
the first deployment needs a root import of the locally built closure before
activation (`sudo nixos-rebuild switch --store-path <system-store-path>`).
Confirm a fresh key-based SSH connection and a reboot before removing the
monitor.

## Directory Structure

- `modules/` - Modular configuration files
  - `programs/` - Application and service configurations
  - `secrets/` - sops-nix secret declarations per host
- `users/` - User-specific configurations
- `hosts/` - Host-specific configurations
- `secrets/` - Encrypted secret files (safe to commit)
- `scripts/` - Helper scripts (pre-commit hooks, etc.)

## OMP Configuration

OMP uses OpenAI only. Use Herdr for Claude sessions. The tracked
[OMP configuration](modules/programs/agents/omp/config.yml) defines model roles,
approval mode, and status-line settings. YOLO mode lets tools run without approval.

Home Manager links `~/.omp/agent/config.yml` to the file under
`~/nixos-config/modules/programs/agents/omp/`. Keep the checkout at
`~/nixos-config`. Changes made through `/settings` or `omp config set` update
the tracked file. Review its Git diff before committing.

Home Manager also generates `~/.omp/agent/mcp.json`, registering the shared
`agentHarnesses.executor.url` and `agentHarnesses.figma.url` as HTTP MCP servers.

Pi, OMP, Codex, Claude Code, and OpenCode use Executor and the
[Figma remote MCP server](https://developers.figma.com/docs/figma-mcp-server/remote-server-installation/).
Slack tools use Executor. Figma connects directly because it does not work
through Executor. Claude Code disables imported claude.ai
connectors; activation also clears its saved project-scoped MCP servers so
projects use the user-scoped entries. This does not delete connectors
from the claude.ai account.

OAuth credentials are local to each harness and are not managed by Nix.
For Figma, use the commands below with `figma` in place of `executor`, or
select Figma in Claude Code.
Authorize once per harness: `/mcp-auth executor` in Pi, `/mcp reauth executor`
in OMP, `codex mcp login executor`, `opencode2 mcp auth executor`, and
`/mcp` → Executor → Authenticate in Claude Code. Run OMP authorization in the
session that needs access. OMP 18.1.13 caches credentials in memory, and
`/mcp reload` does not refresh credentials saved by another process. After
authorizing in a separate OMP process, exit the older session and resume it
with `omp --continue`; a fresh process reads the saved credentials.

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
   sops secrets/framework13.yaml  # or flomac.yaml
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
| `secrets/common.yaml` (optional) | Shared | Framework13 + flomac keys |

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
