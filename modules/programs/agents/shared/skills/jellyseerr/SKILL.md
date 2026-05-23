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

The wrapper script asserts these are set and aborts cleanly otherwise.

## Wrapper script

`scripts/jellyseerr.sh` exposes simple sub-commands so the agent doesn't have
to hand-roll curl invocations for common operations. All output is JSON or
pre-formatted text.

```bash
bash scripts/jellyseerr.sh status                     # /status sanity check
bash scripts/jellyseerr.sh requests                   # pending requests (default)
bash scripts/jellyseerr.sh requests --all             # all requests
bash scripts/jellyseerr.sh request-counts             # totals by state
bash scripts/jellyseerr.sh search "Severance"         # TMDB multi-search
bash scripts/jellyseerr.sh media-status 95396         # media row by mediaId
bash scripts/jellyseerr.sh recently-added             # available media sorted by mediaAdded
bash scripts/jellyseerr.sh approve 42                 # POST /request/42/approve
bash scripts/jellyseerr.sh decline 42                 # POST /request/42/decline
bash scripts/jellyseerr.sh delete-request 42          # DELETE /request/42
bash scripts/jellyseerr.sh users                      # admin: list users
bash scripts/jellyseerr.sh issues                     # open issues
bash scripts/jellyseerr.sh help                       # usage
```

For anything not covered, call the API directly with `$JELLYSEERR_URL` and
`$JELLYSEERR_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: triaging pending requests

1. `bash scripts/jellyseerr.sh requests` — list pending items.
2. Present each to the user with title, year, type (movie/TV), and requester.
3. On user instruction: `approve <id>` or `decline <id>` (confirm first).

## Workflow: searching before adding

1. `bash scripts/jellyseerr.sh search "<title>"` — TMDB multi-search.
2. `bash scripts/jellyseerr.sh media-status <mediaId>` — see if it's already
   tracked / available.
3. Direct the user to the web UI to file a new request (creating requests
   requires a user context beyond a service API key).

## Mutations: confirm first

Always confirm with the user before:

- `approve <id>` — triggers a download in Sonarr/Radarr.
- `decline <id>` — visible to the requester.
- `delete-request <id>` — irreversible.
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
