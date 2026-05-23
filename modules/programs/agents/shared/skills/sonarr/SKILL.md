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

The wrapper script asserts these are set and aborts cleanly otherwise.

## Wrapper script

`scripts/sonarr.sh` exposes simple sub-commands so the agent doesn't have to
hand-roll curl invocations for common operations. All output is JSON or
pre-formatted text.

```bash
bash scripts/sonarr.sh search "Severance"          # TVDB lookup
bash scripts/sonarr.sh search-json "Severance"     # raw JSON for chaining
bash scripts/sonarr.sh exists 81189                # is it in the library?
bash scripts/sonarr.sh add 81189                   # add + search for episodes
bash scripts/sonarr.sh add 81189 --no-search       # add but don't search
bash scripts/sonarr.sh remove 81189                # delete from library, keep files
bash scripts/sonarr.sh remove 81189 --delete-files # delete files too (confirm first!)
bash scripts/sonarr.sh config                      # root folders + quality profiles
bash scripts/sonarr.sh queue                       # active downloads
bash scripts/sonarr.sh calendar [days]             # upcoming releases (default 14d)
bash scripts/sonarr.sh missing                     # monitored episodes with no file
bash scripts/sonarr.sh history [n]                 # recent history (default 50)
bash scripts/sonarr.sh status                      # system/status sanity check
```

For anything not covered, call the API directly with `$SONARR_URL` and
`$SONARR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: adding a show

1. `bash scripts/sonarr.sh search "<title>"` — present results to user with
   `[Title (Year)](https://thetvdb.com/dereferrer/series/<tvdbId>)` links.
2. `bash scripts/sonarr.sh exists <tvdbId>` — confirm it's not already there.
3. `bash scripts/sonarr.sh add <tvdbId>` — adds and starts a search.

## Workflow: routine status checks

Use the high-level subcommands first (`queue`, `calendar`, `missing`, `history`,
`status`). Drop to raw curl for niche queries.

## Mutations: confirm first

Always confirm with the user before:

- `remove <tvdbId> --delete-files` (irreversible — removes media files)
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
