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

The `prowlarr` CLI reports a JSON error envelope when they are missing.

## CLI

Use the installed `prowlarr` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/prowlarr.sh` remains as a compatibility shim for older workflows.

```bash
prowlarr status                                       # system/status sanity check
prowlarr health --limit 25                            # health warnings
prowlarr indexers --limit 50                          # list indexers
prowlarr indexer-stats --limit 50                     # per-indexer usage + failures
prowlarr search "ubuntu 24.04" --limit 25             # search all indexers
prowlarr search "inception" --torrents
prowlarr search "inception" --usenet
prowlarr search "inception" --category 2000
prowlarr tv-search --tvdb 81189 --season 1 --episode 1
prowlarr movie-search --imdb tt0111161
prowlarr movie-search --tmdb 278
prowlarr test <indexerId>                             # test one indexer
prowlarr apps --limit 25                              # connected apps (Sonarr/Radarr/...)
prowlarr sync --confirm-sync                          # push indexer config to apps
prowlarr history --limit 50                           # recent indexer history
```

For anything not covered, call the API directly with `$PROWLARR_URL` and
`$PROWLARR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: finding a release

1. `prowlarr search "<query>"` — top results across all
   indexers, with seeders, size, indexer name, and download URL.
2. Filter with `--torrents`, `--usenet`, or `--category <id>` if the user
   wants narrower results (2000=Movies, 5000=TV, 3000=Audio, 7000=Books).
3. For TV/movie lookups by external ID, prefer `tv-search` / `movie-search` —
   indexers match more accurately than a free-text query.

## Workflow: indexer health check

1. `prowlarr indexer-stats` — shows query counts and failures.
2. `prowlarr health` — surfaces Prowlarr's own warnings.
3. For a specific indexer suspected to be broken, run
   `prowlarr test <indexerId>`.

## Mutations: confirm first

Always confirm with the user before:

- Disabling or deleting an indexer (raw `PUT`/`DELETE` against
  `/api/v1/indexer/{id}`).
- `prowlarr sync --confirm-sync` — this is generally safe (idempotent) but pushes config to every
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
