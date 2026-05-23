# TubeArchivist API Reference

**Service:** TubeArchivist (https://github.com/tubearchivist/tubearchivist)
**Base URL:** `http://192.168.1.56:8000/api`
**Auth:** Django session + CSRF cookies (NOT JWT, NOT api-key)
**Schema:** `/api/schema/` (OpenAPI 3 YAML), human docs at `/api/docs/`
**Last verified:** 2026-05-22 against TA v0.5.10

## Authentication

TubeArchivist runs Django with cookie-based session auth. The login
endpoint returns HTTP 204 and sets two cookies:

- `sessionid` — opaque session token. Lasts 2 days by default.
- `csrftoken` — anti-CSRF token. Lasts 1 year by default.

### Log in

```bash
curl -sS -c /tmp/ta.jar -b /tmp/ta.jar \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"username":"'"$TUBEARCHIVIST_USERNAME"'","password":"'"$TUBEARCHIVIST_PASSWORD"'"}' \
  -i "$TUBEARCHIVIST_URL/api/user/login/"
```

Expected response: `HTTP/1.1 204 No Content` with two `Set-Cookie` headers.

### Read requests (GET)

Cookie jar is enough:

```bash
curl -fsS -b /tmp/ta.jar "$TUBEARCHIVIST_URL/api/channel/" | jq
```

### Mutating requests (POST/PUT/PATCH/DELETE)

You must additionally send the CSRF token in a header and a same-origin
`Referer`. Django's CSRF middleware will reject the request otherwise.

```bash
CSRF=$(awk '$6 == "csrftoken" { print $7 }' /tmp/ta.jar)
curl -fsS -b /tmp/ta.jar \
  -H "Content-Type: application/json" \
  -H "X-CSRFToken: $CSRF" \
  -H "Referer: $TUBEARCHIVIST_URL/" \
  -X POST \
  -d '<json body>' \
  "$TUBEARCHIVIST_URL/api/channel/"
```

### Fetch the full schema

```bash
curl -fsS -b /tmp/ta.jar -H "Accept: application/yaml" \
  "$TUBEARCHIVIST_URL/api/schema/" > /tmp/ta-schema.yaml
```

For human-readable docs, open `$TUBEARCHIVIST_URL/api/docs/` in a browser.

## Endpoints we use

### Health

#### GET /api/health/

Liveness probe served by nginx. Returns `"OK"` (a JSON string) regardless
of session state — useful for monitoring.

```bash
curl -fsS "$TUBEARCHIVIST_URL/api/health/"
# "OK"
```

### Config

#### GET /api/appsettings/config/

Returns the live config (subscriptions, downloads, application).

```json
{
  "application": { "enable_snapshot": true, "enable_cast": false },
  "downloads":   { "limit_speed": null, "sleep_interval": 10, ... },
  "subscriptions": { "channel_size": 50, "playlist_size": 50, ... }
}
```

Note: no `version` field is exposed here; the version string lives in the
OpenAPI schema (`info.version`).

### Stats

#### GET /api/stats/video/

Aggregate video counts and duration.

```json
{ "doc_count": 0, "media_size": 0, "duration": 0, "duration_str": "NA",
  "type_videos": null, "type_shorts": null, "type_streams": null,
  "active_true": null, "active_false": null }
```

#### GET /api/stats/channel/

```json
{ "doc_count": 2, "active_true": 2, "active_false": null,
  "subscribed_true": 2, "subscribed_false": null }
```

#### GET /api/stats/download/

Pending download counts.

```json
{ "pending": null, "ignore": null,
  "pending_videos": null, "pending_shorts": null, "pending_streams": null }
```

#### GET /api/stats/watch/

Watch history aggregates.

```json
{ "total": { "duration": 0, "duration_str": "NA", "items": 0 },
  "unwatched": null, "watched": null }
```

Also available: `/api/stats/biggestchannels/`, `/api/stats/downloadhist/`,
`/api/stats/playlist/`.

### Channels

#### GET /api/channel/

Lists indexed channels.

| Param  | Type    | Description                              |
|--------|---------|------------------------------------------|
| filter | string  | `subscribed` or `unsubscribed`           |
| page   | integer | 0-indexed                                |

```json
{
  "data": [
    {
      "channel_id": "UCxxxxxxxxxxxxxxxxxxxxxx",
      "channel_name": "Example Channel",
      "channel_subscribed": true,
      "channel_last_refresh": "2026-01-01T00:00:00+00:00",
      "channel_subs": 1000000,
      "channel_active": true,
      "channel_tags": [...]
    }
  ]
}
```

#### GET /api/channel/{channel_id}/

Single channel detail.

#### POST /api/channel/

Subscribe or unsubscribe one or more channels. Requires CSRF.

```json
{ "data": [ { "channel_id": "<url-or-UC...>", "channel_subscribed": true } ] }
```

`channel_id` may be either a `UC...` ID or a YouTube URL — TA resolves it
via yt-dlp. Resolution runs in a Celery task (`subscribe_to`), so the
channel will not appear in `GET /api/channel/` immediately; expect a
30-60s delay.

Common 400 error: omitting the `data` envelope returns
`missing expected data key`.

### Videos

#### GET /api/video/

Paginated list of indexed videos.

| Param | Type | Description           |
|-------|------|-----------------------|
| page  | int  | 0-indexed             |
| q     | str  | full-text-ish filter  |

```json
{
  "data": [
    { "youtube_id": "...", "title": "...",
      "channel": { "channel_name": "..." },
      "published": "2024-12-01T00:00:00+00:00",
      "vid_type": "videos",
      "player": { "watched": false } }
  ],
  "paginate": { "page_size": 25, "total_hits": 0, ... }
}
```

#### GET /api/video/{youtube_id}/

Single video detail. Also: `/comment/`, `/nav/`, `/progress/`, `/similar/`
sub-paths.

### Downloads

#### GET /api/download/

Pending download queue, same envelope as `/api/video/`.

#### GET /api/download/{video_id}/

Detail for a queued item.

### Playlists

#### GET /api/playlist/

Indexed playlists.

#### GET /api/playlist/{playlist_id}/

Single playlist.

### Tasks

#### GET /api/task/by-name/

History of Celery tasks grouped by name. Includes status, args, kwargs,
and (on failure) the full traceback.

```json
[
  { "name": "subscribe_to", "status": "SUCCESS",
    "date_done": "2026-01-01T00:00:00.000000+00:00",
    "args": [ "https://www.youtube.com/@ExampleChannel ..." ],
    "kwargs": { "expected_type": "channel" },
    "task_id": "bcbffe84-...",
    "worker": "celery@tubearchivist" }
]
```

#### GET /api/task/by-id/{task_id}/

Single task by ID.

#### GET /api/task/schedule/

Scheduled task definitions.

### Search

#### GET /api/search/

Cross-index search (videos, channels, playlists, fulltext).

| Param | Type | Description       |
|-------|------|-------------------|
| query | str  | search string     |

```json
{
  "queryType": "simple",
  "results": {
    "video_results": [...],
    "channel_results": [...],
    "playlist_results": [...],
    "fulltext_results": [...]
  }
}
```

### User

- `POST /api/user/login/` — log in (returns 204)
- `POST /api/user/logout/` — log out
- `GET /api/user/me/` — current user

## Full path list

From `/api/schema/` (TA v0.5.10):

```
/api/appsettings/backup/                  /api/refresh/
/api/appsettings/backup/{filename}/       /api/search/
/api/appsettings/config/                  /api/stats/biggestchannels/
/api/appsettings/cookie/                  /api/stats/channel/
/api/appsettings/manual-import/           /api/stats/download/
/api/appsettings/membership/profile/      /api/stats/downloadhist/
/api/appsettings/membership/sync/         /api/stats/playlist/
/api/appsettings/membership/token/        /api/stats/video/
/api/appsettings/rescan-filesystem/       /api/stats/watch/
/api/appsettings/snapshot/                /api/task/by-id/{task_id}/
/api/appsettings/snapshot/{snapshot_id}/  /api/task/by-name/
/api/appsettings/token/                   /api/task/by-name/{task_name}/
/api/channel/                             /api/task/notification/
/api/channel/{channel_id}/                /api/task/notification/test/
/api/channel/{channel_id}/aggs/           /api/task/schedule/
/api/channel/{channel_id}/nav/            /api/task/schedule/{task_name}/
/api/channel/search/                      /api/user/account/
/api/download/                            /api/user/login/
/api/download/{video_id}/                 /api/user/logout/
/api/download/aggs/                       /api/user/me/
/api/health/                              /api/video/
/api/notification/                        /api/video/{video_id}/
/api/ping/                                /api/video/{video_id}/comment/
/api/playlist/                            /api/video/{video_id}/nav/
/api/playlist/{playlist_id}/              /api/video/{video_id}/progress/
/api/playlist/custom/                     /api/video/{video_id}/similar/
/api/playlist/custom/{playlist_id}/       /api/watched/
```

## Additional Resources

- [Project repo](https://github.com/tubearchivist/tubearchivist)
- [API docs](http://192.168.1.56:8000/api/docs/) — Swagger UI on the live instance
- [Schema](http://192.168.1.56:8000/api/schema/) — OpenAPI 3 YAML
