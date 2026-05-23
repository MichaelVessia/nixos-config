---
name: tubearchivist
description: Browse, search, and manage channels and downloads in my self-hosted TubeArchivist YouTube archive. Use when the user asks about TubeArchivist, mentions YouTube archiving, asks to subscribe/unsubscribe to a channel, check what's downloading, list indexed videos or channels, inspect Celery task status, or trigger a search.
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

The wrapper script asserts these are set and aborts cleanly otherwise.

## Auth model

TubeArchivist uses Django session auth, not JWT or API keys.

1. `POST /api/user/login/` with `{"username": "...", "password": "..."}` —
   server responds **HTTP 204** and sets `sessionid` + `csrftoken` cookies.
2. Subsequent `GET` calls need only the cookies (`-b jar`).
3. Mutating calls (`POST`, `PUT`, `PATCH`, `DELETE`) additionally need:
   - `X-CSRFToken: <csrftoken cookie value>`
   - `Referer: <TUBEARCHIVIST_URL>/`

The wrapper caches the cookie jar in
`$TMPDIR/tubearchivist-<uid>/<hash>.jar` and reuses it across invocations
(TA's default session lifetime is 2 days). It re-logs in automatically if
the jar is missing or stale.

## Wrapper script

`scripts/tubearchivist.sh` exposes simple sub-commands so the agent doesn't
have to hand-roll the login dance. All output is JSON.

```bash
bash scripts/tubearchivist.sh status                       # health + config + stats
bash scripts/tubearchivist.sh channels                     # subscribed channels
bash scripts/tubearchivist.sh channel-info <channel_id>    # one channel detail
bash scripts/tubearchivist.sh subscribe "<url-or-id>"      # queues Celery task
bash scripts/tubearchivist.sh unsubscribe <channel_id>     # confirm with user first!
bash scripts/tubearchivist.sh videos [n]                   # recent indexed videos
bash scripts/tubearchivist.sh video-info <youtube_id>      # one video detail
bash scripts/tubearchivist.sh downloads                    # pending queue
bash scripts/tubearchivist.sh playlists                    # indexed playlists
bash scripts/tubearchivist.sh tasks                        # Celery task history
bash scripts/tubearchivist.sh search <query>               # cross-index search
```

For anything not covered, call the API directly with the cookie jar — see
`references/api-endpoints.md` and `references/quick-reference.md`.

## Workflow: subscribing to a channel

1. Ask the user for either the YouTube channel URL (e.g.
   `https://www.youtube.com/@ExampleChannel`) or the channel ID (`UC...`).
2. `bash scripts/tubearchivist.sh subscribe "<arg>"` — this queues a Celery
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

- `unsubscribe <channel_id>` — drops the channel and stops future syncs.
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
