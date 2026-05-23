# Prowlarr Skill

Wrapper for the self-hosted Prowlarr (v1 API): search across indexers, inspect
and manage indexer health, sync to Sonarr/Radarr from any agent (Claude, Codex,
opencode).

## What's here

```
prowlarr/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── prowlarr.sh     # Wrapper exposing sub-commands (search, indexers, stats, ...)
└── references/
    ├── api-endpoints.md      # v1 endpoint reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.prowlarr_url.owner = "michaelvessia";
   secrets.prowlarr_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   prowlarr_url: http://192.168.1.192:9696
   prowlarr_api_key: <api key from Prowlarr Settings → General → Security>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/prowlarr_url" ] && export PROWLARR_URL="$(cat "$SECRETS_DIR/prowlarr_url")"
   [ -f "$SECRETS_DIR/prowlarr_api_key" ] && export PROWLARR_API_KEY="$(cat "$SECRETS_DIR/prowlarr_api_key")"
   ```

## Sub-commands

All commands are run as `bash scripts/prowlarr.sh <cmd> [args]`.

| Command                              | What it does                                       |
| ------------------------------------ | -------------------------------------------------- |
| `status`                             | `GET /system/status` — sanity check                |
| `health`                             | Active health warnings                             |
| `indexers [--verbose]`               | List indexers (summary or full JSON)               |
| `indexer-stats`                      | Query counts, grabs, failures per indexer          |
| `search <query> [filters]`           | Search all indexers (`--torrents`, `--usenet`, `--category`, `--limit`) |
| `tv-search --tvdb <id> [...]`        | TV search by TVDB ID (+ optional `--season`, `--episode`) |
| `movie-search --imdb <id>`           | Movie search by IMDB or `--tmdb` ID                |
| `test <indexerId>`                   | Test a specific indexer                            |
| `apps`                               | List connected applications (Sonarr/Radarr/...)    |
| `sync`                               | Push indexer config to all connected apps          |
| `history [n]`                        | Recent indexer history (default 50)                |

## Categories

Standard Newznab/Torznab category IDs the script accepts via `--category`:

| ID    | Category |
| ----- | -------- |
| 2000  | Movies   |
| 5000  | TV       |
| 3000  | Audio    |
| 7000  | Books    |
| 1000  | Console  |
| 4000  | PC       |

Sub-categories like 2040 (Movies/HD), 2045 (Movies/UHD), 5040 (TV/HD) work too.

## Workflows

**Find a release**

```bash
bash scripts/prowlarr.sh search "ubuntu 24.04"
bash scripts/prowlarr.sh search "inception 2160p" --category 2045
bash scripts/prowlarr.sh tv-search --tvdb 81189 --season 1 --episode 1
```

**Check indexer health**

```bash
bash scripts/prowlarr.sh indexer-stats
bash scripts/prowlarr.sh health
bash scripts/prowlarr.sh test 5      # test indexer ID 5
```

**Sync indexers to Sonarr/Radarr**

```bash
bash scripts/prowlarr.sh apps        # see what's connected
bash scripts/prowlarr.sh sync        # push current indexer set
```

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- Prowlarr lives on the LAN (`192.168.1.192:9696`). Off-network access requires
  tailscale or VPN.
- Prowlarr is a search aggregator: it does not download. Hand the release URL
  off to Sonarr/Radarr/SABnzbd.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command can be done with raw curl against `$PROWLARR_URL` using the
  examples in `references/`.
