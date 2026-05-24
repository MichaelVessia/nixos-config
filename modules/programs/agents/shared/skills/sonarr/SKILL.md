---
name: sonarr
description: Search, add, inspect, and manage TV shows in my self-hosted Sonarr library. Use when the user asks about TV shows, mentions Sonarr, asks to add/remove a series, check what's downloading, what's upcoming, what's missing, view queue/history, or trigger searches.
allowed-tools: Bash, WebFetch
---

# Sonarr

Manage my self-hosted Sonarr (v3 API) TV library: search and add shows, inspect
the library, see what's downloading/upcoming/missing, trigger searches, remove
series.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `SONARR_URL` — base URL (no trailing slash)
- `SONARR_API_KEY` — API key
- `SONARR_DEFAULT_QUALITY_PROFILE` — optional, defaults to `1`

The `sonarr` CLI reports a JSON error envelope when they are missing.

## CLI

Use the installed `sonarr` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/sonarr.sh` remains as a compatibility shim for older workflows.

```bash
sonarr search "Severance"                              # TVDB lookup
sonarr exists 81189                                    # is it in the library?
sonarr add 81189                                       # add + search for episodes
sonarr add 81189 --no-search                           # add but don't search
sonarr remove 81189                                    # delete from library, keep files
sonarr remove 81189 --delete-files                     # refuses without confirmation
sonarr remove 81189 --delete-files --confirm-delete-files
sonarr config                                          # root folders + quality profiles
sonarr queue --limit 100                               # active downloads
sonarr calendar --days 14                              # upcoming releases
sonarr missing --limit 100                             # monitored episodes with no file
sonarr history --limit 50                              # recent history
sonarr status                                          # system/status sanity check
```

For anything not covered, call the API directly with `$SONARR_URL` and
`$SONARR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: adding a show

1. `sonarr search "<title>"` — present results to user with
   `[Title (Year)](https://thetvdb.com/dereferrer/series/<tvdbId>)` links.
2. `sonarr exists <tvdbId>` — confirm it's not already there.
3. `sonarr add <tvdbId>` — adds and starts a search.

## Workflow: routine status checks

Use the high-level subcommands first (`queue`, `calendar`, `missing`, `history`,
`status`). Drop to raw curl for niche queries.

## Mutations: confirm first

Always confirm with the user before:

- `remove <tvdbId> --delete-files --confirm-delete-files` (irreversible — removes media files)
- Bulk monitor/unmonitor toggles
- Removing queue items with blocklist=true
- Any custom DELETE/PUT against `/api/v3`

## References

- `references/api-endpoints.md` — full v3 endpoint reference with
  request/response shapes
- `references/quick-reference.md` — copy-paste curl recipes for common ops
- `references/troubleshooting.md` — auth, connection, and common error fixes

## Notes

- API is v3. Older `/api/` (v1) paths return 404.
- `X-Api-Key` header beats `?apikey=` (avoids leaking the key into logs).
- Commands are async — `GET /api/v3/command/{id}` polls a command's status.
- Sonarr lives on the LAN. If `SONARR_URL` is unreachable, surface that to the
  user rather than guessing.
