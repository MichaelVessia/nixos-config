---
name: jellyseerr
description: Browse, search, approve, decline, and inspect media requests in my self-hosted Jellyseerr. Use when the user asks about Jellyseerr, mentions media requests, asks to approve/decline a request, search for a movie or show to request, check what was recently added, list users, or view open issues.
allowed-tools: Bash, WebFetch
---

# Jellyseerr

Manage my self-hosted Jellyseerr (Overseerr-compatible v1 API) for Jellyfin:
view and triage pending media requests, search TMDB for movies/TV, check media
status, list recently added items, and inspect open user issues.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `JELLYSEERR_URL` — base URL (no trailing slash)
- `JELLYSEERR_API_KEY` — API key from Jellyseerr Settings → General

The `jellyseerr` CLI reports a JSON error envelope when they are missing.

## CLI

Use the installed `jellyseerr` CLI for common operations. It always emits a
single JSON envelope with `ok`, `command`, `result` or `error`, and
`next_actions`. `scripts/jellyseerr.sh` remains as a compatibility shim for
older workflows.

```bash
jellyseerr status                                     # /status sanity check
jellyseerr requests --limit 25                        # pending requests (default)
jellyseerr requests --all --limit 50                  # all requests
jellyseerr request-counts                             # totals by state
jellyseerr search "Severance" --limit 10              # TMDB multi-search
jellyseerr media-status 95396                         # media row by mediaId
jellyseerr recently-added --limit 25                  # available media sorted by mediaAdded
jellyseerr approve 42 --confirm-approve               # POST /request/42/approve
jellyseerr decline 42 --confirm-decline               # POST /request/42/decline
jellyseerr delete-request 42 --confirm-delete-request # DELETE /request/42
jellyseerr users --limit 50                           # admin: list users
jellyseerr issues --limit 50                          # open issues
```

For anything not covered, call the API directly with `$JELLYSEERR_URL` and
`$JELLYSEERR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: triaging pending requests

1. `jellyseerr requests` — list pending items.
2. Present each to the user with title, year, type (movie/TV), and requester.
3. On user instruction: `approve <id> --confirm-approve` or
   `decline <id> --confirm-decline` (confirm first).

## Workflow: searching before adding

1. `jellyseerr search "<title>"` — TMDB multi-search.
2. `jellyseerr media-status <mediaId>` — see if it's already
   tracked / available.
3. Direct the user to the web UI to file a new request (creating requests
   requires a user context beyond a service API key).

## Mutations: confirm first

Always confirm with the user before:

- `jellyseerr approve <id> --confirm-approve` — triggers a download in Sonarr/Radarr.
- `jellyseerr decline <id> --confirm-decline` — visible to the requester.
- `jellyseerr delete-request <id> --confirm-delete-request` — irreversible.
- Any custom POST/PUT/DELETE against `/api/v1`.

## References

- `references/api-endpoints.md` — v1 endpoint reference focused on the calls
  this skill makes.
- `references/quick-reference.md` — copy-paste curl recipes for common ops.
- `references/troubleshooting.md` — auth, connection, key rotation, off-LAN.

## Notes

- API is v1 under `/api/v1`. Jellyseerr forks Overseerr; the API surface
  matches https://api-docs.overseerr.dev/.
- `X-Api-Key` header beats `?apikey=` (avoids leaking the key into logs).
- The instance lives on the LAN at `http://192.168.1.83:5055`. Off-network
  access requires tailscale or a VPN — surface that to the user rather than
  guessing.
- Approving a request enqueues work in the linked Sonarr/Radarr — pair with
  the `sonarr`/`radarr` skills to follow up on downloads.
