# Jellyfin Skill

Wrapper for the self-hosted Jellyfin server: inspect status, users, libraries,
sessions, what's playing, recently added items, search, library counts, and
scheduled tasks from any agent (Claude, Codex, opencode).

## What's here

```
jellyfin/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── jellyfin.sh     # Wrapper exposing sub-commands (status, sessions, …)
└── references/
    ├── api-endpoints.md      # Endpoint reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.jellyfin_url.owner = "michaelvessia";
   secrets.jellyfin_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   jellyfin_url: http://192.168.1.21:8096
   jellyfin_api_key: <api key from Dashboard → API Keys>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/jellyfin_url" ] && export JELLYFIN_URL="$(cat "$SECRETS_DIR/jellyfin_url")"
   [ -f "$SECRETS_DIR/jellyfin_api_key" ] && export JELLYFIN_API_KEY="$(cat "$SECRETS_DIR/jellyfin_api_key")"
   ```

Jellyfin auth uses the Emby-derived header `X-Emby-Token`, not `X-Api-Key`.

## Sub-commands

All commands are run as `bash scripts/jellyfin.sh <cmd> [args]`.

| Command                       | What it does                                          |
| ----------------------------- | ----------------------------------------------------- |
| `status`                      | `GET /System/Info` — sanity check                     |
| `users`                       | All users (id, name, lastActivityDate, isAdmin)       |
| `libraries`                   | `GET /Library/VirtualFolders`                         |
| `sessions`                    | `GET /Sessions` — every active session                |
| `now-playing`                 | Sessions filtered to those with `NowPlayingItem`      |
| `recently-added [n]`          | Latest n items (default 20) for the first user        |
| `item-search <query>`         | Search Movies, Series, Episodes (limit 25)            |
| `library-stats`               | `GET /Items/Counts`                                   |
| `scheduled-tasks`             | All scheduled tasks with state and last result        |
| `run-task <taskId>`           | `POST /ScheduledTasks/Running/<id>` (confirm first!)  |

## Workflows

**Who's watching right now?**

```bash
bash scripts/jellyfin.sh now-playing
```

**What's new this week?**

```bash
bash scripts/jellyfin.sh recently-added 20
```

**Find that one show**

```bash
bash scripts/jellyfin.sh item-search "Severance"
```

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- Jellyfin lives on the LAN (`192.168.1.21:8096`). Off-network access requires
  tailscale or VPN.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command can be done with raw curl against `$JELLYFIN_URL` using the
  examples in `references/`.
- Full API reference: <https://api.jellyfin.org/>.
