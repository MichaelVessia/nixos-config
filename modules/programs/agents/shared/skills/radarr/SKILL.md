---
name: radarr
description: Search, add, inspect, and manage movies in my self-hosted Radarr library. Use when the user asks about movies, mentions Radarr, asks to add/remove a film, check what's downloading, what's upcoming, what's missing, view queue/history, manage collections, or trigger searches.
allowed-tools: Bash, WebFetch
---

# Radarr

Manage my self-hosted Radarr (v3 API) movie library: search and add movies,
inspect the library, see what's downloading/upcoming/missing, trigger searches,
add full collections, remove movies.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `RADARR_URL` — base URL (no trailing slash)
- `RADARR_API_KEY` — API key
- `RADARR_DEFAULT_QUALITY_PROFILE` — optional, defaults to `1`

The wrapper script asserts these are set and aborts cleanly otherwise.

## Wrapper script

`scripts/radarr.sh` exposes simple sub-commands so the agent doesn't have to
hand-roll curl invocations for common operations. All output is JSON or
pre-formatted text.

```bash
bash scripts/radarr.sh search "Inception"           # TMDB lookup
bash scripts/radarr.sh search-json "Inception"      # raw JSON for chaining
bash scripts/radarr.sh exists 27205                 # is it in the library?
bash scripts/radarr.sh add 27205                    # add + search
bash scripts/radarr.sh add 27205 --no-search        # add but don't search
bash scripts/radarr.sh add-collection 10            # whole Star Wars collection
bash scripts/radarr.sh collection-info 10           # inspect a collection
bash scripts/radarr.sh remove 27205                 # delete from library, keep files
bash scripts/radarr.sh remove 27205 --delete-files  # delete files too (confirm first!)
bash scripts/radarr.sh config                       # root folders + quality profiles
bash scripts/radarr.sh queue                        # active downloads
bash scripts/radarr.sh calendar [days]              # upcoming releases (default 30d)
bash scripts/radarr.sh missing                      # monitored movies with no file
bash scripts/radarr.sh history [n]                  # recent history (default 50)
bash scripts/radarr.sh status                       # system/status sanity check
```

For anything not covered, call the API directly with `$RADARR_URL` and
`$RADARR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: adding a movie

1. `bash scripts/radarr.sh search "<title>"` — present results to user with
   `[Title (Year)](https://themoviedb.org/movie/<tmdbId>)` links. Note any
   `[Collection: …]` tag and offer to add the whole collection.
2. `bash scripts/radarr.sh exists <tmdbId>` — confirm it's not already there.
3. `bash scripts/radarr.sh add <tmdbId>` — adds and starts a search.

## Workflow: adding a collection

1. Add one movie from the collection first (Radarr only knows about a
   collection once at least one of its movies is in the library).
2. `bash scripts/radarr.sh collection-info <collectionTmdbId>` — sanity check.
3. `bash scripts/radarr.sh add-collection <collectionTmdbId>` — adds everything
   else and flips `monitored`/`searchOnAdd` on so future entries auto-add.

## Workflow: routine status checks

Use the high-level subcommands first (`queue`, `calendar`, `missing`, `history`,
`status`). Drop to raw curl for niche queries.

## Mutations: confirm first

Always confirm with the user before:

- `remove <tmdbId> --delete-files` (irreversible — removes media files)
- `add-collection` on large franchises (can add dozens of movies)
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
- `minimumAvailability` defaults to `released` when adding; override in the
  payload if you want to grab pre-releases or in-cinema films.
- Radarr lives on the LAN. If `RADARR_URL` is unreachable, surface that to the
  user rather than guessing.
