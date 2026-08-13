# Immich Skill

Wrapper for the self-hosted Immich photo/video library: inspect, search,
browse from any agent (Claude, Codex, opencode). Read-only.

## What's here

```
immich/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── immich.sh       # Wrapper exposing sub-commands (status, stats, search, …)
└── references/
    ├── api-endpoints.md      # Endpoint reference, verified live against v2.5.6
    ├── quick-reference.md    # Copy-paste curl recipes
    └── troubleshooting.md    # Auth/permissions/connection fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.immich_url.owner = "michaelvessia";
   secrets.immich_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   immich_url: http://192.168.1.82:2283
   immich_api_key: <api key from Immich Account Settings → API Keys>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/immich_url" ] && export IMMICH_URL="$(cat "$SECRETS_DIR/immich_url")"
   [ -f "$SECRETS_DIR/immich_api_key" ] && export IMMICH_API_KEY="$(cat "$SECRETS_DIR/immich_api_key")"
   ```

When creating the key, grant the permissions you actually need. For this
read-only skill: `server.read`, `asset.read`, `album.read`, `user.read`,
`person.read`, `tag.read`, `job.read`, and `adminUser.read` if you want
quota/isAdmin in `users`. Immich rejects everything else with 403.

## Sub-commands

All commands are run as `bash scripts/immich.sh <cmd> [args]`.

| Command                 | What it does                                       |
| ----------------------- | -------------------------------------------------- |
| `status`                | Combined `/server/version` + `/server/ping`        |
| `stats`                 | Photos/videos counts and bytes, per-user breakdown |
| `storage`               | Server disk free + library disk usage              |
| `users`                 | All users (id, name, email, isAdmin, quota)        |
| `me`                    | The user attached to the active API key            |
| `albums [n]`            | First `n` albums (default 25)                      |
| `album-info <id>`       | Full album detail                                  |
| `search <query>`        | CLIP smart search, metadata filename fallback      |
| `recent [n]`            | Most recent assets (default 25)                    |
| `people [n]`            | People (default 25, hidden excluded)               |
| `person-info <id>`      | Full person detail                                 |
| `jobs`                  | Background job queues + counts                     |
| `library-stats`         | Alias for `stats`                                  |
| `tags`                  | All tags                                           |

## Workflows

**Find a photo**

```bash
bash scripts/immich.sh search "kids at the beach"
# inspect by id
curl -sS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/assets/<id>" | jq
```

**Daily status check**

```bash
bash scripts/immich.sh status
bash scripts/immich.sh storage
bash scripts/immich.sh jobs
```

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- Immich lives on the LAN (`192.168.1.82:2283`, LXC 117 on Proxmox).
  Off-network access requires Tailscale.
- The wrapper is intentionally read-only. Mutations (delete asset, merge
  people, modify album) belong in the UI for now — the SKILL.md documents
  the requirement to confirm with the user before any future mutation
  sub-command runs.
