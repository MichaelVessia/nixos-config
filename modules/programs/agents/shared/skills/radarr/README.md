# Radarr Skill

Wrapper for the self-hosted Radarr (v3 API): search, add, inspect, and manage
the movie library from any agent (Claude, Codex, opencode).

## What's here

```
radarr/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── radarr.sh       # Wrapper exposing sub-commands (search, add, queue, …)
└── references/
    ├── api-endpoints.md      # v3 endpoint reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.radarr_url.owner = "michaelvessia";
   secrets.radarr_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   radarr_url: http://192.168.1.186:7878
   radarr_api_key: <api key from Radarr Settings → General>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/radarr_url" ] && export RADARR_URL="$(cat "$SECRETS_DIR/radarr_url")"
   [ -f "$SECRETS_DIR/radarr_api_key" ] && export RADARR_API_KEY="$(cat "$SECRETS_DIR/radarr_api_key")"
   ```

Optional override: set `RADARR_DEFAULT_QUALITY_PROFILE` in the shell or a
matching sops secret if you want `add` to default to something other than
profile id `1`.

## Sub-commands

All commands are run as `bash scripts/radarr.sh <cmd> [args]`.

| Command                                       | What it does                                    |
| --------------------------------------------- | ----------------------------------------------- |
| `status`                                      | `GET /system/status` — sanity check             |
| `config`                                      | Root folders + quality profiles                 |
| `search <query>`                              | TMDB lookup, top 10 results                     |
| `search-json <query>`                         | Same lookup, raw JSON for chaining              |
| `exists <tmdbId>`                             | Is the movie already in the library?            |
| `add <tmdbId> [profileId] [--no-search]`      | Add movie; searches by default                  |
| `add-collection <colTmdbId> [--no-search]`    | Add every movie in a TMDB collection            |
| `collection-info <colTmdbId>`                 | Show Radarr's record for a collection           |
| `remove <tmdbId> [--delete-files]`            | Delete from library (files optional)            |
| `queue`                                       | Active download queue                           |
| `calendar [days]`                             | Upcoming releases, default 30 days              |
| `missing [n]`                                 | Monitored movies with no file                   |
| `history [n]`                                 | Recent history, default 50 items                |

## Workflows

**Adding a movie**

```bash
bash scripts/radarr.sh search "Inception"
bash scripts/radarr.sh exists 27205
bash scripts/radarr.sh add 27205
```

**Adding a collection** — Radarr only knows about a collection once one of its
movies is already in the library. Add a single movie first, then:

```bash
bash scripts/radarr.sh collection-info 10
bash scripts/radarr.sh add-collection 10
```

**Cleaning up failed downloads** — see
`references/quick-reference.md#workflow-clean-up-failed-downloads`.

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- Radarr lives on the LAN (`192.168.1.186:7878`). Off-network access requires
  tailscale or VPN.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command can be done with raw curl against `$RADARR_URL` using the
  examples in `references/`.
