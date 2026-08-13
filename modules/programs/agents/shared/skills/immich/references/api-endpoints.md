# Immich API Reference

**Server version verified against:** v2.5.6
**Base path:** `/api/`
**Authentication header:** `x-api-key` (lowercase)
**Last verified:** 2026-05-23

> Immich's API evolves quickly. Pin the docs URL to the running server version:
> https://immich.app/docs/api/ — the OpenAPI spec ships with each release at
> `https://github.com/immich-app/immich/blob/v2.5.6/open-api/immich-openapi-specs.json`.
> If a field below disagrees with what you see, check the spec for the current
> server version first.

## Authentication

Immich v2 uses **per-permission API keys**. Each key carries an explicit list
of allowed scopes (e.g. `asset.read`, `album.write`, `adminUser.read`). A key
that can hit `/api/server/ping` may still 403 on `/api/users` if it lacks
`user.read`. Find or create keys in the UI under Account Settings → API Keys.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/ping"
```

The wrapper uses these scopes:

- `server.read` — status, version, ping, statistics, storage
- `asset.read` — search, recent
- `album.read` — albums, album-info
- `user.read` — me
- `adminUser.read` — users (admin endpoint); wrapper falls back to `user.read`
- `person.read` — people, person-info
- `job.read` — jobs
- `tag.read` — tags

## Quick Start

Credentials come from sops-nix and are exported by
`modules/programs/shell.nix`:

```bash
IMMICH_URL=http://192.168.1.82:2283
IMMICH_API_KEY=<key from Immich → Account Settings → API Keys>
```

Sanity check:

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/ping" | jq
# => {"res":"pong"}
```

## Endpoints used by the wrapper

### GET /api/server/version

Returns server version as integer parts.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/version"
# => {"major":2,"minor":5,"patch":6}
```

### GET /api/server/ping

Liveness check. Cheap and unauthenticated-by-scope (any valid key works).

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/ping"
# => {"res":"pong"}
```

### GET /api/server/statistics

Photo/video counts and bytes used, both server-wide and per-user. Requires a
key with `server.read`. The `usageByUser` array includes `quotaSizeInBytes`
which is null when no quota is set.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/statistics"
```

```json
{
  "photos": 55411,
  "videos": 6248,
  "usage": 45183557018,
  "usagePhotos": 9329064128,
  "usageVideos": 35854492890,
  "usageByUser": [
    {
      "userId": "…",
      "userName": "Michael Vessia",
      "photos": 54495,
      "videos": 6061,
      "usage": 35592049819,
      "usagePhotos": 7357190139,
      "usageVideos": 28234859680,
      "quotaSizeInBytes": null
    }
  ]
}
```

### GET /api/server/storage

Disk free space for the library mountpoint, formatted twice (human + raw).

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/storage"
```

```json
{
  "diskSize": "15.7 TiB",
  "diskUse": "6.3 TiB",
  "diskAvailable": "9.4 TiB",
  "diskSizeRaw": 17268860911616,
  "diskUseRaw": 6907314307072,
  "diskAvailableRaw": 10361546604544,
  "diskUsagePercentage": 40
}
```

### GET /api/users

Returns the **public** view of every user — id, email, name, profile image,
avatar color. No `isAdmin`, no quota. Requires `user.read`.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/users"
```

### GET /api/admin/users

Admin view of all users. Includes `isAdmin`, `quotaSizeInBytes`,
`quotaUsageInBytes`, `status`, `oauthId`, `deletedAt`. Requires
`adminUser.read`. The wrapper's `users` sub-command prefers this and falls
back to `/api/users` on 403.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/admin/users"
```

### GET /api/users/me

Returns the user attached to the API key, with admin/storage label/quota.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/users/me"
```

### GET /api/albums

Returns every album the caller can see, **unpaginated**. The wrapper
client-side trims to `n`. Each entry includes `id`, `albumName`,
`assetCount`, `createdAt`, `updatedAt`, `ownerId`, `owner`, `albumUsers`,
`shared`, `hasSharedLink`, `albumThumbnailAssetId`.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/albums"
```

### GET /api/albums/{id}

Full album detail, including `assets` (full asset records) and `albumUsers`.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/albums/<albumId>"
```

### POST /api/search/smart

CLIP-based semantic search. Body shape:

```json
{ "query": "kids at the beach", "size": 25 }
```

```bash
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"sunset","size":25}' \
  "$IMMICH_URL/api/search/smart"
```

Response shape:

```json
{
  "albums": { "total": 0, "count": 0, "items": [], "facets": [] },
  "assets": { "total": 25, "count": 25, "items": [ /* asset records */ ], "facets": [] }
}
```

Smart search requires the machine-learning service to be reachable and the
CLIP embedding job to have run. When it returns zero results, the wrapper
falls back to metadata search by `originalFileName`.

### POST /api/search/metadata

Structured search over asset metadata. Useful body keys:

- `size` (int) — page size
- `page` (int) — page number
- `order` — `"asc"` or `"desc"`
- `originalFileName` — substring match on filename
- `type` — `"IMAGE"` or `"VIDEO"`
- `takenAfter`, `takenBefore` — ISO timestamps
- `personIds`, `tagIds`, `city`, `country`, `make`, `model`, `lensModel`

```bash
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"size":25,"order":"desc"}' \
  "$IMMICH_URL/api/search/metadata"
```

The wrapper's `recent` uses `{size, order:"desc"}`; `search` falls back to
`{originalFileName: <query>, size: 25}`.

### GET /api/people

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  "$IMMICH_URL/api/people?withHidden=false&size=25"
```

Returns `{total, hidden, hasNextPage, people: [...]}`. Each person has
`id`, `name`, `birthDate`, `thumbnailPath`, `isHidden`, `isFavorite`,
`updatedAt`.

### GET /api/people/{id}

Full person detail (same fields as the list entry; some installs also
return `faces` here, but v2.5.6 does not).

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  "$IMMICH_URL/api/people/<personId>"
```

### GET /api/jobs

Snapshot of every background job queue. Requires `job.read` (admin keys get
this by default).

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/jobs"
```

Response is an object keyed by queue name. Each value has
`queueStatus: {isPaused, isActive}` and
`jobCounts: {active, completed, failed, delayed, waiting, paused}`.

Common queues: `thumbnailGeneration`, `metadataExtraction`,
`videoConversion`, `smartSearch`, `faceDetection`, `facialRecognition`,
`backgroundTask`, `library`, `migration`, `sidecar`, `storageTemplateMigration`,
`notifications`, `backupDatabase`.

### GET /api/tags

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/tags"
```

Each tag: `id`, `name`, `value`, `createdAt`, `updatedAt`.

## Endpoints not used by the wrapper but worth knowing

| Endpoint                                | Notes                                  |
| --------------------------------------- | -------------------------------------- |
| `GET /api/assets/{id}`                  | Full asset record                       |
| `GET /api/assets/{id}/original`         | Download original file                  |
| `GET /api/assets/{id}/thumbnail`        | Thumbnail (`?size=preview` or `thumbnail`) |
| `POST /api/search/random`               | Random asset sample                     |
| `GET /api/server/about`                 | Build info (version, nodejs, ffmpeg, …) |
| `GET /api/server/features`              | Which optional features are enabled     |
| `GET /api/libraries`                    | External libraries                      |
| `GET /api/sessions`                     | Active auth sessions                    |
| `POST /api/jobs/{name}`                 | Trigger a job (admin, **mutation**)     |
| `PUT /api/people/{id}`                  | Rename person (admin, **mutation**)     |
| `DELETE /api/assets`                    | Trash assets (**mutation**)             |

Anything marked mutation needs explicit user confirmation per SKILL.md.

## Version notes

| Server version | Doc verified | Notes                                          |
| -------------- | ------------ | ---------------------------------------------- |
| v2.5.6         | 2026-05-23   | Initial documentation. Per-permission API keys. |

## Additional resources

- Official docs: https://immich.app/docs/api/
- OpenAPI spec (pinned): https://github.com/immich-app/immich/blob/v2.5.6/open-api/immich-openapi-specs.json
- Repo: https://github.com/immich-app/immich
