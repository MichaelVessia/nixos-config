---
name: jellyfin
description: "Inspect my self-hosted Jellyfin media server: server status, users, libraries, sessions, now-playing, recently-added, item search, library counts, and scheduled tasks. Use when the user asks about Jellyfin, what's playing, who's watching, what was just added, library size, or asks to run a Jellyfin task."
allowed-tools: Bash, WebFetch
---

# Jellyfin

Inspect my self-hosted Jellyfin server: status, users, libraries, active
sessions, what's currently playing, recently added items, item search, library
counts, and scheduled tasks.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `JELLYFIN_URL` — base URL (no trailing slash), e.g. `http://192.168.1.21:8096`
- `JELLYFIN_API_KEY` — API key from Dashboard → API Keys

The `jellyfin` CLI reports a JSON error envelope when they are missing.
Jellyfin inherits auth headers from Emby, so the header name is `X-Emby-Token`
(not `X-Api-Key`).

## CLI

Use the installed `jellyfin` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/jellyfin.sh` remains as a compatibility shim for older workflows.

```bash
jellyfin status                                # /System/Info sanity check
jellyfin users                                 # all users with last activity
jellyfin libraries                             # virtual folders (libraries)
jellyfin sessions                              # every active session
jellyfin now-playing                           # sessions with NowPlayingItem
jellyfin recently-added --limit 20             # latest items
jellyfin item-search "<query>" --limit 25      # search Movies/Series/Episodes
jellyfin library-stats                         # /Items/Counts
jellyfin scheduled-tasks                       # task list with state
jellyfin run-task <taskId> --confirm-run-task  # POST /ScheduledTasks/Running/<id>
```

For anything not covered, call the API directly with `$JELLYFIN_URL` and the
`X-Emby-Token: $JELLYFIN_API_KEY` header — see `references/api-endpoints.md`
and `references/quick-reference.md`.

## Workflow: who's watching?

1. `jellyfin now-playing` — current streams with user, device,
   item, and play method.
2. `jellyfin sessions` — full session list if no one is
   actively playing (idle clients still show up).

## Workflow: what's new?

1. `jellyfin recently-added --limit 10` — last 10 items added across
   the libraries the first user can see.
2. `jellyfin library-stats` — totals (Movies, Series,
   Episodes, etc.).

## Mutations: confirm first

Always confirm with the user before:

- `jellyfin run-task <taskId> --confirm-run-task` (kicks off a server task; some are I/O heavy)
- Any custom POST/PUT/DELETE against the Jellyfin API

## References

- `references/api-endpoints.md` — endpoint reference with request/response
  shapes
- `references/quick-reference.md` — copy-paste curl recipes for common ops
- `references/troubleshooting.md` — auth, connection, and common error fixes

## Notes

- Header is `X-Emby-Token` (Jellyfin forked Emby and kept the name).
- Many `/Items` endpoints are user-scoped — they require a `userId` in the
  path or query. The CLI picks the first non-disabled user.
- Recently-added is per-user; an admin sees everything, restricted users only
  see their own libraries.
- Jellyfin lives on the LAN. If `JELLYFIN_URL` is unreachable, surface that to
  the user rather than guessing.
- Full API reference: <https://api.jellyfin.org/>.
