---
name: tubearchivist
description: Browse and manage my TubeArchivist archive. Use for channels, videos, downloads, tasks, search, ordinary subscriptions, or a curated creator import that queues popular videos and exposes the channel in Jellyfin.
allowed-tools: Bash, WebFetch
---

# TubeArchivist

Manage my self-hosted TubeArchivist instance: subscribe to YouTube channels,
inspect what's indexed, watch the download queue, and check Celery worker
state. Lives at `http://192.168.1.56:8000` (LXC 120). Storage is on the NAS
under `/mnt/synology-media/youtube`, bind-mounted as `/mnt/media/youtube` in
the LXC and exposed as `/youtube` to the TubeArchivist app.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `TUBEARCHIVIST_URL` — base URL (no trailing slash)
- `TUBEARCHIVIST_USERNAME` — admin username
- `TUBEARCHIVIST_PASSWORD` — admin password

The `tubearchivist` CLI reports a JSON error envelope when they are missing.

## Auth model

TubeArchivist uses Django session auth, not JWT or API keys.

1. `POST /api/user/login/` with `{"username": "...", "password": "..."}` —
   server responds **HTTP 204** and sets `sessionid` + `csrftoken` cookies.
2. Subsequent `GET` calls need only the cookies (`-b jar`).
3. Mutating calls (`POST`, `PUT`, `PATCH`, `DELETE`) additionally need:
   - `X-CSRFToken: <csrftoken cookie value>`
   - `Referer: <TUBEARCHIVIST_URL>/`

The CLI handles login, cookies, and CSRF headers for supported commands.

## CLI

Use the installed `tubearchivist` CLI for common operations. It always emits a
single JSON envelope with `ok`, `command`, `result` or `error`, and
`next_actions`. `scripts/tubearchivist.sh` remains as a compatibility shim for
older workflows.

```bash
tubearchivist status                                       # health + config + stats
tubearchivist channels --limit 50                          # subscribed channels
tubearchivist channel-info <channel_id>                    # one channel detail
tubearchivist subscribe "<url-or-id>"                      # queues Celery resolution
tubearchivist unsubscribe <channel_id> --confirm-unsubscribe
tubearchivist videos --limit 25                            # recent indexed videos
tubearchivist video-info <youtube_id>                      # one video detail
tubearchivist downloads --limit 25                         # pending queue
tubearchivist playlists --limit 25                         # indexed playlists
tubearchivist tasks --limit 25                             # Celery task history
tubearchivist search <query> --limit 25                    # cross-index search
```

For anything not covered, call the API directly after logging in — see
`references/api-endpoints.md` and `references/quick-reference.md`.

## Workflow: subscribing to a channel

1. Ask the user for either the YouTube channel URL (e.g.
   `https://www.youtube.com/@ExampleChannel`) or the channel ID (`UC...`).
2. `tubearchivist subscribe "<arg>"` — this queues a Celery
   `subscribe_to` task. TA does the resolution.
3. The channel will not appear in `channels` immediately. Celery typically
   takes 30-60 seconds. Poll `tasks` to confirm the `subscribe_to` task
   went `SUCCESS` before reporting back to the user.
4. If the task fails (most often a yt-dlp 404 on the handle), surface the
   error message to the user — they probably typed the handle wrong.

## Workflow: routine status checks

Use `status` for a one-shot overview (health, version, totals). Drop to
`tasks` to see what Celery is up to. `downloads` lists items the worker has
queued for yt-dlp.

## Workflow: curated channel import

Use this when the user wants a creator subscribed in TubeArchivist and surfaced
under a friendly name in Jellyfin. Confirm first because it subscribes to a
channel, downloads videos, and changes locked Jellyfin metadata.

Required environment:

- `TUBEARCHIVIST_URL`, `TUBEARCHIVIST_USERNAME`, `TUBEARCHIVIST_PASSWORD`
- `JELLYFIN_URL`, `JELLYFIN_API_KEY`

Resolve the channel before committing:

```bash
bash scripts/add-youtube-channel.sh <handle-or-url> <friendly-name> --resolve-only
```

Then run:

```bash
bash scripts/add-youtube-channel.sh <handle-or-url> <friendly-name> [--top N] [--recent K]
```

Defaults are `--top 20 --recent 30`. The script resolves the handle, subscribes
through TubeArchivist, queues the most-viewed videos among the recent sample,
waits for the first file, scans Jellyfin, renames the channel folder, and locks
its `Name` field. It returns a JSON summary. Surface authentication failures,
bad handles, download timeouts, or a missing Jellyfin YouTube library rather
than claiming partial success.

## Storage layout

TubeArchivist writes downloaded videos to `/youtube` inside the LXC, which
is a symlink to `/mnt/media/youtube` (the NAS bind mount). On the host
that's `/mnt/synology-media/youtube`. One folder per channel:

```
/mnt/synology-media/youtube/<Channel Name>/...
/mnt/synology-media/youtube/<Another Channel>/...
```

## Mutations: confirm first

Always confirm with the user before:

- `tubearchivist unsubscribe <channel_id> --confirm-unsubscribe` — drops the channel and stops future syncs.
- Any custom `DELETE` against `/api/video/`, `/api/channel/`, or
  `/api/playlist/` — these remove indexed data.
- Bulk operations against `/api/appsettings/*` (snapshots, backups,
  rescan-filesystem).

## References

- `references/api-endpoints.md` — endpoint reference and the full schema
  fetch (`/api/schema/`)
- `references/quick-reference.md` — copy-paste curl recipes (login + jar,
  list channels, subscribe with CSRF, view tasks, queue)
- `references/troubleshooting.md` — auth, CSRF, yt-dlp resolution, and
  connection error fixes

## Notes

- API base is `/api/` (no `v1`/`v2` prefix). The schema is
  `/api/schema/` (OpenAPI 3 YAML), human docs at `/api/docs/`.
- Health probe: `GET /api/health/` returns `"OK"` (handled by nginx in
  front of the Django app).
- Subscribing queues a Celery task — the channel does not appear in the
  channel list until that task completes (30-60s typical).
- TubeArchivist lives on the LAN. If `TUBEARCHIVIST_URL` is unreachable,
  surface that to the user rather than guessing.
