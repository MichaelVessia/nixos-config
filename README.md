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

Framework13 installs the T3 Code desktop app through Home Manager from the
locked `llm-agents` input. After rebuilding, launch it with `t3code-desktop`.
Its first-run setup connects to the local backend; remote computers can be
added from the app.

### Forge desktop

`forge` reuses Framework13's Niri desktop and `michaelvessia` Home Manager
profile. Shared system settings live in `modules/desktop-system.nix`;
Framework-specific audio rules and VM settings remain in `hosts/framework13`.
Forge uses its installer-generated Btrfs mounts, initial `system.stateVersion`
of `26.05`, and the proprietary NVIDIA driver with Wayland modesetting.

Keep the checkout at `/home/michaelvessia/nixos-config`. Before the first
activation, securely provision the personal age key at
`~/.config/sops/age/keys.txt` with mode `600`. Forge reuses the encrypted personal
secrets declared in `modules/secrets/default.nix`; no private keys belong in Git.
Build on an authenticated machine if Forge does not yet have private GitHub access:

```bash
nix build .#nixosConfigurations.forge.config.system.build.toplevel --no-link
```

On Forge, apply the configuration with
`sudo nixos-rebuild switch --flake ~/nixos-config#forge` once GitHub access is
configured, or import an authenticated machine's built closure as root and use
`sudo nixos-rebuild switch --store-path <system-store-path>` for the first deployment.
Tailscale and agent OAuth authorization are separate machine-local steps.
Forge authorizes the Framework and Flomac SSH public keys. For T3 Code's
desktop-managed SSH connection, use `michaelvessia@forge` over Tailscale,
not its LAN address. Establish a normal SSH connection from the client first
to trust the host key. The desktop app starts the remote T3 backend; provider
authentication remains local to Forge.
Forge disables accepted Tailscale subnet routes because it is already on the
advertised homelab LAN. Accepting that subnet sends LAN replies through
`tailscale0`, breaking direct SSH access. The Framework keeps route acceptance
enabled for access away from home. Forge's Tailscale operator is `michaelvessia`.
Forge uses `vaults.deviceName = "forge"` and generates its own Syncthing identity.
Register that identity in `modules/programs/vault-devices.nix` and rebuild peers
before expecting bidirectional vault synchronization.

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

Foundry's `opentelemetry-collector.service` sends host metrics to SigNoz every
30 seconds after rebuilding. CPU, memory, filesystem, disk, network, paging,
load, and process counts use `host.name=foundry` and `service.name=foundry-host`;
application logs and traces are not collected. In SigNoz, filter host metrics
by `host.name=foundry`. Collection is outbound-only and opens no Foundry ports.
The private-LAN OTLP endpoint is `192.168.1.10:4317`; SigNoz CT 124 must allow
Foundry's LAN address (`192.168.1.18`) through its ingestion firewall. Keep that
address stable in DHCP or update the allowlist when it changes.

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

## Shared Agent Skills

Personal skills live under `modules/programs/agents/shared/skills/` and are
discovered automatically by `modules/programs/agents/shared.nix`. Home Manager
installs per-skill links for the shared bundle and agent-specific skill directories,
preserving externally installed sibling skills.

The `immich-albums` skill searches event photos and videos through Executor,
checks visual samples and capture metadata, handles motion-photo companions, and
creates verified private albums without changing originals. It is enabled only
on homelab-enabled hosts (`framework13`), not `foundry` or `flomac`. Rebuild to
install it, then start a new agent session to load its catalog entry.

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

## Obsidian vaults

Home Manager manages Syncthing devices, folder shares, ignore rules, and versioning.
Open each folder below as a separate Obsidian vault. Do not open or sync `~/vaults`
as one folder.

| Vault | flomac | foundry | framework13 |
| --- | --- | --- | --- |
| `~/vaults/brain` | Shared | Shared | Shared after rebuild |
| `~/vaults/flosports` | Shared | Shared | Absent |
| `~/vaults/private` | Absent | Absent | Personal notes, initially empty |

`brain` is for reviewed general knowledge. Work notes stay in `flosports` until
reviewed. Personal notes stay in `private`. Capture tools default to the restricted
vault for the host, never to `brain`.

- `modules/programs/vaults.nix` defines paths and ignore rules.
- `modules/programs/vault-devices.nix` records public device IDs, profiles, and
  Tailscale addresses. Identity keys stay on each device, outside Git.
- `modules/programs/syncthing.nix` shares `brain` with all registered peers and
  restricts `flosports` and `private` to peers with the same profile.
- Each user configuration selects its device name and `work` or `personal` profile.
- Obsidian settings, Git history, local trash, and local Claude permissions do not
  sync. Notes, attachments, and vault instructions do sync.
- Syncthing keeps staggered versions for 90 days on each device. This protects
  against incoming changes, not local changes. Keep separate backups.
- TCP port 22000 is allowed on the NixOS Tailscale interface. The Syncthing API
  stays on localhost. Routine setup does not require the web interface.

### Activate the prepared work vaults

The work vault was moved from `~/obsidian` to `~/vaults/flosports`. Obsidian's vault
registry and active Codex automation paths on flomac were updated. `brain` contains
only its sharing instructions. Foundry has initial copies of both vaults.

The new Syncthing identities are already generated in
`~/Library/Application Support/Syncthing` on flomac and `~/.local/state/syncthing`
on foundry. Preserve these directories when rebuilding. Syncthing is not started
by the migration itself. Rebuild both hosts to apply the service configuration.
Use `hosts/flomac` as the macOS deployment entry point described above.

If the Raycast Obsidian quicklink still uses `flo-notes` or `obsidian`, change it to
`obsidian://open?vault=flosports`. Reopen agent workspaces that still use the old
vault path. Historical notes and saved session records retain their original paths.

Pixel 7 and `proxmox-syncthing` are also registered as personal peers for `brain`
and `private`. Their existing Syncthing installations still need matching folder
shares. They are excluded from `flosports`. Devices without a fixed address use
Syncthing discovery. Keep their old vault shares until the new shares are checked.

### Finish the personal migration

1. Keep the existing personal vault and sync shares until the migration is checked.
2. Framework13 is registered with its existing device ID. For another personal
   device, read its existing identity with `syncthing device-id`. Do not generate
   a replacement identity for an existing installation.
3. Add each additional device ID, `profile = "personal"`, and Tailscale TCP address
   to `modules/programs/vault-devices.nix`.
4. Rebuild all participating hosts so both sides have the device and folder shares.
5. Copy personal notes and attachments into `~/vaults/private`, then open that
   folder in Obsidian. Keep its `.stignore` file managed by Home Manager.
6. Check note edits and attachments on each intended device before retiring the old
   vault share. Move only reviewed general notes into `brain`.

Framework13 temporarily preserves unmanaged devices and folders because its current
configuration has not been inventoried. After all existing shares are declared in
Nix, remove its `overrideDevices = false` and `overrideFolders = false` overrides.
Never include flomac or foundry in the personal-only `private` share.
