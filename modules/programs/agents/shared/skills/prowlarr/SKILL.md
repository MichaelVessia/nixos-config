---
name: prowlarr
description: Search across indexers and manage my self-hosted Prowlarr. Use when the user asks about indexer search, finding a release, indexer health/stats, listing or testing indexers, syncing indexers to Sonarr/Radarr, or mentions Prowlarr.
allowed-tools: Bash, WebFetch
---

# Prowlarr

Manage my self-hosted Prowlarr (v1 API) indexer aggregator: search across all
configured indexers, inspect indexer health and stats, test/enable/disable
indexers, list connected apps, sync indexer config to Sonarr/Radarr/etc.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `PROWLARR_URL` — base URL (no trailing slash)
- `PROWLARR_API_KEY` — API key

The wrapper script asserts these are set and aborts cleanly otherwise.

## Wrapper script

`scripts/prowlarr.sh` exposes simple sub-commands so the agent doesn't have to
hand-roll curl invocations for common operations. All output is JSON or
pre-formatted text.

```bash
bash scripts/prowlarr.sh status                       # system/status sanity check
bash scripts/prowlarr.sh health                       # health warnings
bash scripts/prowlarr.sh indexers                     # list indexers (summary)
bash scripts/prowlarr.sh indexers --verbose           # full indexer JSON
bash scripts/prowlarr.sh indexer-stats                # per-indexer usage + failures
bash scripts/prowlarr.sh search "ubuntu 24.04"        # search all indexers
bash scripts/prowlarr.sh search "inception" --torrents
bash scripts/prowlarr.sh search "inception" --usenet
bash scripts/prowlarr.sh search "inception" --category 2000
bash scripts/prowlarr.sh tv-search --tvdb 81189 --season 1 --episode 1
bash scripts/prowlarr.sh movie-search --imdb tt0111161
bash scripts/prowlarr.sh test <indexerId>             # test one indexer
bash scripts/prowlarr.sh apps                         # connected apps (Sonarr/Radarr/...)
bash scripts/prowlarr.sh sync                         # push indexer config to apps
bash scripts/prowlarr.sh history [n]                  # recent indexer history (default 50)
```

For anything not covered, call the API directly with `$PROWLARR_URL` and
`$PROWLARR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: finding a release

1. `bash scripts/prowlarr.sh search "<query>"` — top results across all
   indexers, with seeders, size, indexer name, and download URL.
2. Filter with `--torrents`, `--usenet`, or `--category <id>` if the user
   wants narrower results (2000=Movies, 5000=TV, 3000=Audio, 7000=Books).
3. For TV/movie lookups by external ID, prefer `tv-search` / `movie-search` —
   indexers match more accurately than a free-text query.

## Workflow: indexer health check

1. `bash scripts/prowlarr.sh indexer-stats` — shows query counts and failures.
2. `bash scripts/prowlarr.sh health` — surfaces Prowlarr's own warnings.
3. For a specific indexer suspected to be broken, run
   `bash scripts/prowlarr.sh test <indexerId>`.

## Mutations: confirm first

Always confirm with the user before:

- Disabling or deleting an indexer (raw `PUT`/`DELETE` against
  `/api/v1/indexer/{id}`).
- `sync` — this is generally safe (idempotent) but pushes config to every
  connected app; mention that side effect.
- Any custom DELETE/PUT against `/api/v1`.

## References

- `references/api-endpoints.md` — v1 endpoint reference with request/response
  shapes
- `references/quick-reference.md` — copy-paste curl recipes for common ops
- `references/troubleshooting.md` — auth, connection, and common error fixes

## Notes

- API is v1. There is no v3 — using `/api/v3/...` returns 404.
- `X-Api-Key` header beats `?apikey=` (avoids leaking the key into logs).
- Prowlarr is search-only: it does not download. Hand a release URL to
  Sonarr/Radarr/SABnzbd to actually grab it.
- Category IDs follow the Newznab/Torznab standard (Movies 2000-2099, TV
  5000-5099, etc.).
- Prowlarr lives on the LAN. If `PROWLARR_URL` is unreachable, surface that to
  the user rather than guessing.
