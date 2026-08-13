# Immich Quick Reference

Copy-paste curl recipes for the operations you'll actually need. All assume
`IMMICH_URL` and `IMMICH_API_KEY` are exported by sops-nix via
`modules/programs/shell.nix`.

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/ping" | jq
```

## Server info

### Version + ping

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/version" | jq
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/ping"    | jq
```

### Full about (nodejs, ffmpeg, libvips versions)

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/about" | jq
```

### Library statistics

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/statistics" | jq
```

### Disk free / storage

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/storage" | jq
```

## Users

```bash
# Public view (no admin fields)
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/users" | jq

# Admin view (isAdmin, quota) — needs adminUser.read scope
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/admin/users" | jq

# Whoever owns this key
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/users/me" | jq
```

## Albums

```bash
# All albums (unpaginated; consumer trims)
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/albums" \
  | jq '.[] | {id, albumName, assetCount, ownerId}'

# Single album with full asset list
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/albums/<albumId>" | jq

# Just the asset ids in an album
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/albums/<albumId>" \
  | jq -r '.assets[].id'
```

## Assets

### Asset record by id

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/assets/<assetId>" | jq
```

### Download original

```bash
# Streams the original file. Use -o to write to disk.
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  -o "/tmp/<assetId>.orig" \
  "$IMMICH_URL/api/assets/<assetId>/original"
```

### Thumbnail (preview-size jpeg)

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  -o "/tmp/<assetId>.jpg" \
  "$IMMICH_URL/api/assets/<assetId>/thumbnail?size=preview"
```

## Search

### Smart (CLIP) search

```bash
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"kids at the beach","size":25}' \
  "$IMMICH_URL/api/search/smart" \
  | jq '.assets.items[] | {id, originalFileName, fileCreatedAt}'
```

### Recent uploads (metadata, no query)

```bash
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"size":25,"order":"desc"}' \
  "$IMMICH_URL/api/search/metadata" \
  | jq '.assets.items[] | {id, originalFileName, fileCreatedAt, type}'
```

### Filename substring

```bash
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"originalFileName":"IMG_4664","size":25}' \
  "$IMMICH_URL/api/search/metadata" | jq
```

### Photos shot on a specific camera in a date range

```bash
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "make":"Apple",
    "model":"iPhone 14 Pro",
    "takenAfter":"2025-12-01T00:00:00Z",
    "takenBefore":"2026-01-01T00:00:00Z",
    "size":100,
    "order":"desc"
  }' \
  "$IMMICH_URL/api/search/metadata" | jq
```

## People

```bash
# List visible people
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  "$IMMICH_URL/api/people?withHidden=false&size=25" | jq

# Single person
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  "$IMMICH_URL/api/people/<personId>" | jq

# All photos of a person (via metadata search)
curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"personIds":["<personId>"],"size":50,"order":"desc"}' \
  "$IMMICH_URL/api/search/metadata" | jq
```

## Jobs

```bash
# All background queues with paused/active flags and counts
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/jobs" | jq

# Only queues with anything waiting/failed
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/jobs" \
  | jq 'to_entries | map(select(.value.jobCounts.waiting > 0 or .value.jobCounts.failed > 0)) | from_entries'
```

## Tags

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/tags" \
  | jq '.[] | {id, name}'
```

## Workflows

### Workflow: find a photo and download the original

```bash
# 1. Search semantically
id=$(curl -fsS -X POST \
  -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"red sunset over the ocean","size":1}' \
  "$IMMICH_URL/api/search/smart" | jq -r '.assets.items[0].id')

# 2. Inspect
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/assets/$id" | jq

# 3. Download
curl -fsS -H "x-api-key: $IMMICH_API_KEY" \
  -o "/tmp/$id.bin" \
  "$IMMICH_URL/api/assets/$id/original"
```

### Workflow: who uses the most storage?

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/statistics" \
  | jq '.usageByUser
        | sort_by(-.usage)
        | .[]
        | {userName, photos, videos, usageBytes: .usage}'
```

### Workflow: snapshot of background job health

```bash
curl -fsS -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/jobs" \
  | jq 'to_entries
        | map({queue: .key, waiting: .value.jobCounts.waiting, failed: .value.jobCounts.failed, paused: .value.queueStatus.isPaused})'
```
