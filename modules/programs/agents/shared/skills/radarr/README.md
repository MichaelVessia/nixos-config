# Radarr Skill

CLI for the self-hosted Radarr (v3 API): search, add, inspect, and manage the
movie library from any agent (Claude, Codex, opencode).

## What's here

```
radarr/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── radarr.sh       # Compatibility shim for older workflows
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

## CLI Commands

All commands are run as `radarr <cmd> [args]`. The shim keeps older positional
forms working where practical.

| Command                                       | What it does                                    |
| --------------------------------------------- | ----------------------------------------------- |
| `status`                                      | `GET /system/status` — sanity check             |
| `config`                                      | Root folders + quality profiles                 |
| `search <query>`                              | TMDB lookup, top 10 results                     |
| `exists <tmdbId>`                             | Is the movie already in the library?            |
| `add <tmdbId> [--quality-profile id] [--no-search]` | Add movie; searches by default            |
| `add-collection <colTmdbId> --confirm-add-collection [--no-search]` | Add every movie in a TMDB collection |
| `collection-info <colTmdbId>`                 | Show Radarr's record for a collection           |
| `remove <tmdbId> [--delete-files --confirm-delete-files]` | Delete from library (files optional) |
| `queue --limit <n>`                           | Active download queue                           |
| `calendar --days <n>`                         | Upcoming releases                               |
| `missing --limit <n>`                         | Monitored movies with no file                   |
| `history --limit <n>`                         | Recent history                                  |

## Workflows

**Adding a movie**

```bash
radarr search "Inception"
radarr exists 27205
radarr add 27205
```

**Adding a collection** — Radarr only knows about a collection once one of its
movies is already in the library. Add a single movie first, then:

```bash
radarr collection-info 10
radarr add-collection 10 --confirm-add-collection
```

**Cleaning up failed downloads** — see
`references/quick-reference.md#workflow-clean-up-failed-downloads`.

## Notes

- The installed `radarr` CLI emits a single JSON envelope for every command.
- Radarr lives on the LAN (`192.168.1.186:7878`). Off-network access requires
  tailscale or VPN.
- Raw API examples remain in `references/` for operations not covered by the CLI.
