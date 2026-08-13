# Jellyseerr Skill

Wrapper for the self-hosted Jellyseerr (v1 API, Overseerr-compatible): browse
and triage media requests, search TMDB, inspect media status, and review open
issues from any agent (Claude, Codex, opencode).

## What's here

```
jellyseerr/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── jellyseerr.sh   # Wrapper exposing sub-commands (requests, approve, …)
└── references/
    ├── api-endpoints.md      # v1 endpoint reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.jellyseerr_url.owner = "michaelvessia";
   secrets.jellyseerr_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   jellyseerr_url: http://192.168.1.83:5055
   jellyseerr_api_key: <api key from Jellyseerr Settings → General>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/jellyseerr_url" ] && export JELLYSEERR_URL="$(cat "$SECRETS_DIR/jellyseerr_url")"
   [ -f "$SECRETS_DIR/jellyseerr_api_key" ] && export JELLYSEERR_API_KEY="$(cat "$SECRETS_DIR/jellyseerr_api_key")"
   ```

## Sub-commands

All commands are run as `bash scripts/jellyseerr.sh <cmd> [args]`.

| Command                       | What it does                                      |
| ----------------------------- | ------------------------------------------------- |
| `status`                      | `GET /status` — sanity check                      |
| `requests`                    | Pending requests (top 50, newest first)           |
| `requests --all`              | All requests regardless of state                  |
| `request-counts`              | `GET /request/count` — totals by state            |
| `search <query>`              | TMDB multi-search (movies + TV)                   |
| `media-status <mediaId>`      | `GET /media/<id>` — single media row              |
| `recently-added`              | Available media sorted by `mediaAdded`            |
| `approve <requestId>`         | `POST /request/<id>/approve`                      |
| `decline <requestId>`         | `POST /request/<id>/decline`                      |
| `delete-request <requestId>`  | `DELETE /request/<id>`                            |
| `users`                       | `GET /user` — admin only                          |
| `issues`                      | `GET /issue` — open issues                        |

## Workflows

**Triage pending requests**

```bash
bash scripts/jellyseerr.sh requests
bash scripts/jellyseerr.sh approve 42      # after user confirmation
```

**Check whether a title is already tracked**

```bash
bash scripts/jellyseerr.sh search "severance"
bash scripts/jellyseerr.sh media-status 95396
```

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- Jellyseerr lives on the LAN (`192.168.1.83:5055`). Off-network access
  requires tailscale or VPN.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command can be done with raw curl against `$JELLYSEERR_URL` using the
  examples in `references/`.
- The Jellyseerr API matches Overseerr's surface, documented at
  https://api-docs.overseerr.dev/.
