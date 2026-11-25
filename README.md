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

### Deploying to other hosts

`deploy` ([deploy-rs](https://github.com/serokell/deploy-rs), in the dev shell)
pushes a host's configuration over SSH. Run it from the repository root, where
direnv loads the dev shell, or prefix it with `nix develop --command`.

```bash
deploy -s .#foundry                          # one host
deploy -s --targets .#foundry .#dev-machine  # several hosts
deploy -s .                                  # every host in deploy.nodes
deploy -s --dry-activate .#foundry           # build and show changes only
```

- `-s` (`--skip-checks`) skips `nix flake check`. The flake defines no deploy
  checks, and the check evaluates every host.
- Nodes are in `deploy.nodes` in `flake.nix`: foundry, forge, framework13,
  dev-machine, and flomac. Use `reload` for the machine you are on.
- The deploying machine evaluates the flake and builds each closure, then
  copies it to the target, so targets never build. Only the deploying machine
  needs private GitHub access (`garage`). The target's Nix daemon must accept
  unsigned paths from the SSH user: root, or a user in `trusted-users`.
- Flomac cannot build Linux closures. Add `--remote-build` when you deploy
  from flomac (`fleet` does this). Flomac's own node always builds on flomac.
- deploy-rs logs in as root by SSH key on foundry, forge, and framework13, so
  it asks for no password. Dev-machine logs in as `michaelvessia` and has
  passwordless sudo. Flomac logs in as `michael.vessia` and asks for the sudo
  password.
- If a host stops answering SSH after activation, deploy-rs rolls it back
  (magic rollback). If one host fails in a multi-host run, deploy-rs also rolls
  back the hosts it already deployed in that run.

`fleet` does both steps in one command. It runs `deploy --test` on every node
whose `groups` contain `from-<this host>`, which activates the configuration
without a boot loader change. One `[y/N]` prompt then approves the persistent
switch on those nodes and `reload` on this machine. If you answer no, the
tested configurations stay active until the next reboot. A failed host does
not roll back the hosts that succeeded. Update a node's
groups when you change which keys it accepts.

Foundry, forge, and framework13 must authorize the deploying machine's SSH key
for `root`. Your normal user is not in Nix `trusted-users` on them, because a
trusted user can get root. On dev-machine and flomac, the SSH user must be in
`trusted-users`. With the current keys:

| Deploy from | Hosts |
|---|---|
| framework13 | foundry, forge |
| forge | framework13 |
| flomac | foundry, dev-machine |
| foundry | dev-machine, once foundry has private GitHub access |

Dev-machine deploys nothing. Only flomac and foundry may reach it, and its key
on flomac is for scrawl captures.

Keep framework13 isolated from flomac: do not authorize flomac's key on it or
give flomac an SSH alias for it. A host accepts root deploys (framework13
accepts forge's key, with sshd on Tailscale only) only after one `reload` on
it applies `hosts/<name>/default.nix`. A forge deploy needs
private GitHub access on forge. Flomac uses Determinate Nix, so its
`trusted-users` is in `/etc/nix/nix.custom.conf`. Foundry, forge, and
dev-machine can reach flomac over SSH, but a deploy from them also needs
private GitHub access there and macOS Remote Login on flomac. Until then, use
`reload` on flomac.

Framework13 and Forge install the official T3 Code nightly desktop AppImage
through Home Manager, pinned by version and checksum in
`modules/programs/t3code-nightly/package.nix`. After rebuilding, launch it
with `t3code-desktop` or **T3 Code (Nightly)** from the application launcher.
Personal hosts (`framework13` and `forge`) stay separate from the work/hub
setup (`flomac`, `dev-machine`, `foundry`): they use personal Antigravity,
direct xAI (`grok login`), and direct OpenAI Codex (`codex login`), with no
CLIProxyAPI hub, Claude Code, OpenCode, or Pi. In-app automatic updates are
disabled because Nix manages the installed desktop version; update the
package's version and checksum to upgrade. Forge also runs `t3code.service`
with `linger` and Tailscale Serve so Framework13 can connect to it remotely.

Flomac installs the Namespace CLI as `namespace-devbox`; `devbox` remains
Jetify Devbox. After rebuilding, run `namespace-devbox login` to authenticate.
Use `namespace-devbox configure-ssh <name>` to configure a Namespace devbox
for the T3 Code SSH connection. Run it without `sudo`; Home Manager includes
the generated `~/.namespace/ssh/*.ssh` files in its managed SSH configuration.

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
Forge authorizes the Framework and Foundry SSH public keys (not Flomac). It
enables `linger` and `modules/agent-memory.nix` for `t3code.service`, and it
does not install the `flo` CLI.
Forge disables accepted Tailscale subnet routes because it is already on the
advertised homelab LAN. Accepting that subnet sends LAN replies through
`tailscale0`, breaking direct SSH access. The Framework keeps route acceptance
enabled for access away from home. Forge's Tailscale operator is `michaelvessia`.
Forge uses `vaults.deviceName = "forge"` and generates its own Syncthing identity.
Register that identity in `modules/programs/vault-devices.nix` and rebuild peers
before expecting bidirectional vault synchronization.

Forge uses the shared host metrics collector. In Maple, filter host metrics
by `host.name=forge` or `service.name=forge-host`.

### Foundry headless devbox

`foundry` is an x86_64 NixOS devbox with the login user `michaelvessia`, no desktop,
and a Btrfs SSD. Its installer-generated mounts are preserved in
`hosts/foundry/hardware-configuration.nix`; regenerate that file on the machine
if the disk layout changes. The headless Home Manager profile in
`users/foundry/home.nix` reuses the shell, Git, Neovim, Zellij, Worktrunk, and
agent modules without importing the desktop package collection.

Keep the repository at `/home/michaelvessia/nixos-config`: agent settings use writable
links into that checkout. Agent OAuth credentials and private GitHub access
must be authorized separately; no private credentials are copied automatically.
SSH accepts the configured Framework and Mac public keys; password and root
SSH logins are disabled. Sudo still requires the user's password. The `michaelvessia`
user is trusted by Nix, like the existing dev host's admin user.

Foundry includes the Google Cloud CLI. After rebuilding, sign in as the
`michaelvessia` user on Foundry with `gcloud auth login --no-launch-browser`.
Follow the printed URL in your browser and enter the authorization code in
that terminal. Agents on Foundry can then use this login. For Cloud Build
checks, pass `--project=flosports-174016`; the account needs permission to
read the build and its logs. Credentials remain outside this repository.

Foundry joins the tailnet; the shared SSH module defines `ssh foundry` as
`michaelvessia@foundry` through MagicDNS. Rebuild the client machine to activate the
shortcut. The `michaelvessia` user is a Tailscale operator and lingers, so the T3
Code user service can publish itself with Tailscale Serve.

In Maple, filter Foundry host metrics by `host.name=foundry` or
`service.name=foundry-host`.

Build from an existing authenticated x86_64 machine:

```bash
nix build .#nixosConfigurations.foundry.config.system.build.toplevel --no-link
```

After the first deployment, deploy updates from an authenticated machine with
`deploy -s .#foundry` (see "Deploying to other hosts"). Foundry needs no
private GitHub credentials.

The initial stock installation does not yet trust the `michaelvessia` Nix user, so
the first deployment needs a root import of the locally built closure before
activation (`sudo nixos-rebuild switch --store-path <system-store-path>`).
Confirm a fresh key-based SSH connection and a reboot before removing the
monitor.

### Dev Machine (EC2)

`dev-machine` is an x86_64 NixOS EC2 instance in flostag, created by the
`dev-machine` Terraform module in `flocasts/floai`
(`devops/terraform/env/dev/michaelvessia/`). First boot runs
`nixos-rebuild switch --flake github:MichaelVessia/nixos-config#dev-machine`
without GitHub credentials, so the host must not use private inputs such as
`garage`, or sops secrets. Follow the module README for
first access (Session Manager, then `sudo tailscale up`), and keep Tailscale
and sshd enabled, or the box becomes unreachable once `bootstrap_access` is off.

`users/dev-machine/home.nix` keeps only Claude Code, Codex, herdr, the shell
and Git modules, a short skill list (`agentSkills.personal`), and some
`scripts/` groups (`scripts.groups`). Agents write notes to the local
`~/vaults/flosports`, which does not sync. Sudo needs no password because the
user has none.

`devm` (`scripts/dev-machine/devm`) wraps the floai workflow and the box:
`devm start`, `devm stop`, `devm ssh`, `devm rebuild` (switch to this flake's
`master`), `devm status` and `devm session` (need the `flostag` AWS profile, or
set `DEVM_AWS_PROFILE`), `devm apply`, and `devm destroy`. Run `devm help` for
the list. `ssh dev-machine` reaches the box over Tailscale.

## Host metrics in Maple

The shared collector sends CPU, memory, filesystem, disk, network, load, and
process metrics every 30 seconds to Maple over OTLP HTTP at
`https://maple.home.vessia.net`. Caddy admits sources listed in
`modules/homelab/topology.json`. The collector sends host metrics without opening
inbound ports on the monitored hosts.

NixOS uses `modules/host-metrics.nix`. Flomac uses
`modules/host-metrics-darwin.nix` and a root launchd daemon with logs in
`/var/log/otelcol-host-metrics.log`. Darwin omits paging and created-process
metrics. The Framework13 development VM disables host metrics.

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

## Agent MCP servers

Pi, Codex, Claude Code, OpenCode, and Grok use Executor and the
[Figma remote MCP server](https://developers.figma.com/docs/figma-mcp-server/remote-server-installation/).
Slack tools use Executor. Figma connects directly because it does not work
through Executor. Claude Code disables imported claude.ai
connectors; activation also clears its saved project-scoped MCP servers so
projects use the user-scoped entries. This does not delete connectors
from the claude.ai account.

On work hosts (`cliproxyHub.enable = true`), Grok routes through the
CLIProxyAPI hub and reads Claude Code's setup through its compatibility layer
(skills, `CLAUDE.md`, MCP servers from `~/.claude.json`, and hooks). On
personal hosts (`framework13` and `forge`, `cliproxyHub.enable = false`), Grok
authenticates directly with xAI (`grok login`), disables Claude compatibility,
reads `~/.grok/AGENTS.md` and `~/.agents/skills`, and configures the personal
`executor` MCP natively in `~/.grok/config.toml`. Cursor compatibility is off
everywhere. On personal hosts (`cliproxyHub.enable = false`), Codex also
authenticates directly (`codex login`) and configures only the personal
`executor` MCP, skipping the CLIProxyAPI hub, work MCP servers
(`executor-flosports`, `figma`), and work Datadog telemetry.

Claude and Codex use the Nix-pinned t3-pstack plugin. Activation installs it
into their default and configured T3 homes. Personal skills remain separate.
See [t3-pstack setup](modules/programs/agents/pstack/README.md) for model rules,
checks, and updates. The upstream plugin supports Claude and Codex in T3;
Grok and OpenCode retain shared instructions and personal skills.

On framework13 and Forge, Codex, Antigravity, and Grok use the same local
Executor v2 CLI sign-in. Sign in once on each host and start new agent
sessions:

```bash
executor login --host https://executor.home.vessia.net
```

The CLI stores the credential locally. Home Manager configures each client
to start `executor mcp` with the personal server origin. Use
`executor whoami --host https://executor.home.vessia.net` to check
the sign-in.

Work hosts use `executor-flosports` at `https://executor.flosports.tv/mcp`.
Authorize the work connection in each client. Use `/mcp-auth executor-flosports`
in Pi, `codex mcp login executor-flosports` in Codex, and
`opencode2 mcp auth executor-flosports` in OpenCode. In Claude Code or Grok,
open the MCP panel and authenticate the connection.

## Remote T3 threads

Use the native T3 connection for the current environment. For remote T3,
discover the target host in the personal Executor. Keep each remote T3 OAuth
connection in Executor. The FloSports instance cannot reach the private
Tailscale addresses.

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
