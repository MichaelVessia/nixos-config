# Sonarr Skill

Wrapper for the self-hosted Sonarr (v3 API): search, add, inspect, and manage
the TV library from any agent (Claude, Codex, opencode).

## What's here

```
sonarr/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── sonarr.sh       # Wrapper exposing sub-commands (search, add, queue, …)
└── references/
    ├── api-endpoints.md      # v3 endpoint reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.sonarr_url.owner = "michaelvessia";
   secrets.sonarr_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   sonarr_url: http://192.168.1.38:8989
   sonarr_api_key: <api key from Sonarr Settings → General>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/sonarr_url" ] && export SONARR_URL="$(cat "$SECRETS_DIR/sonarr_url")"
   [ -f "$SECRETS_DIR/sonarr_api_key" ] && export SONARR_API_KEY="$(cat "$SECRETS_DIR/sonarr_api_key")"
   ```

Optional override: set `SONARR_DEFAULT_QUALITY_PROFILE` in the shell or a
matching sops secret if you want `add` to default to something other than
profile id `1`.

## Sub-commands

All commands are run as `bash scripts/sonarr.sh <cmd> [args]`.

| Command                              | What it does                                  |
| ------------------------------------ | --------------------------------------------- |
| `status`                             | `GET /system/status` — sanity check           |
| `config`                             | Root folders + quality profiles               |
| `search <query>`                     | TVDB lookup, top 10 results                   |
| `search-json <query>`                | Same lookup, raw JSON for chaining            |
| `exists <tvdbId>`                    | Is the show already in the library?           |
| `add <tvdbId> [profileId] [--no-search]` | Add show; searches for episodes by default |
| `remove <tvdbId> [--delete-files]`   | Delete from library (files optional)          |
| `queue`                              | Active download queue                         |
| `calendar [days]`                    | Upcoming episodes, default 14 days            |
| `missing`                            | Monitored episodes with no file               |
| `history [n]`                        | Recent history, default 50 items              |

## Workflows

**Adding a show**

```bash
bash scripts/sonarr.sh search "Severance"
bash scripts/sonarr.sh exists 371980
bash scripts/sonarr.sh add 371980
```

**Cleaning up failed downloads** — see
`references/quick-reference.md#workflow-clean-up-failed-downloads`.

**Bulk monitor a season** — see
`references/quick-reference.md#workflow-batch-monitor-seasons`.

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- Sonarr lives on the LAN (`192.168.1.38:8989`). Off-network access requires
  tailscale or VPN.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command can be done with raw curl against `$SONARR_URL` using the
  examples in `references/`.
