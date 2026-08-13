# TubeArchivist Quick Reference

Copy-paste curl recipes. All commands assume the env vars are already
exported by sops-nix (no `source` step required):

```bash
echo "$TUBEARCHIVIST_URL"        # http://192.168.1.56:8000
echo "$TUBEARCHIVIST_USERNAME"   # admin
echo "$TUBEARCHIVIST_PASSWORD"   # (sensitive)
```

## Login + cookie jar

```bash
JAR=/tmp/ta.jar

curl -sS -c "$JAR" -b "$JAR" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"username":"'"$TUBEARCHIVIST_USERNAME"'","password":"'"$TUBEARCHIVIST_PASSWORD"'"}' \
  "$TUBEARCHIVIST_URL/api/user/login/"
# Response is HTTP 204 No Content; cookies are now in $JAR.
```

Grab CSRF from the jar (needed for any mutating request):

```bash
CSRF=$(awk '$6 == "csrftoken" { print $7 }' "$JAR")
```

## Health probe

```bash
curl -fsS "$TUBEARCHIVIST_URL/api/health/"
# "OK"
```

## Stats / config (overview)

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/appsettings/config/" | jq
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/stats/video/" | jq
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/stats/channel/" | jq
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/stats/download/" | jq
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/stats/watch/" | jq
```

## Channels

### List subscribed channels

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/channel/" \
  | jq '.data[] | {name: .channel_name, id: .channel_id, subscribed: .channel_subscribed}'
```

### Filter by subscription status

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/channel/?filter=subscribed" | jq
```

### One channel detail

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/channel/UCxxxxxxxxxxxxxxxxxxxxxx/" | jq
```

### Subscribe (CSRF required)

```bash
curl -fsS -b "$JAR" \
  -H "Content-Type: application/json" \
  -H "X-CSRFToken: $CSRF" \
  -H "Referer: $TUBEARCHIVIST_URL/" \
  -X POST \
  -d '{"data":[{"channel_id":"https://www.youtube.com/@ExampleChannel","channel_subscribed":true}]}' \
  "$TUBEARCHIVIST_URL/api/channel/"
```

The response confirms the request shape; the actual resolution happens in
a Celery `subscribe_to` task. Poll task status to confirm completion:

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/task/by-name/" \
  | jq '.[] | select(.name == "subscribe_to") | {status, date_done, args}'
```

### Unsubscribe

```bash
curl -fsS -b "$JAR" \
  -H "Content-Type: application/json" \
  -H "X-CSRFToken: $CSRF" \
  -H "Referer: $TUBEARCHIVIST_URL/" \
  -X POST \
  -d '{"data":[{"channel_id":"UCxxxxxxxxxxxxxxxxxxxxxx","channel_subscribed":false}]}' \
  "$TUBEARCHIVIST_URL/api/channel/"
```

## Videos

### Recent indexed videos

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/video/?page=0" \
  | jq '.data[] | {youtube_id, title, channel: .channel.channel_name, published, watched: .player.watched}'
```

### One video

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/video/dQw4w9WgXcQ/" | jq
```

## Download queue

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/download/" \
  | jq '{total: .paginate.total_hits, items: [.data[] | {youtube_id, title, status}]}'
```

## Playlists

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/playlist/" | jq
```

## Tasks (Celery worker state)

```bash
# All recent tasks
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/task/by-name/" | jq

# Just failures
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/task/by-name/" \
  | jq '[.[] | select(.status == "FAILURE") | {name, date_done, args, result}]'

# One task by ID
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/task/by-id/<task_id>/" | jq
```

## Search

```bash
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/search/?query=blippi" \
  | jq '{
      videos: .results.video_results // [] | length,
      channels: .results.channel_results // [] | length,
      playlists: .results.playlist_results // [] | length
    }'
```

## Workflows

### Workflow: subscribe and confirm

```bash
# 1. Subscribe (queues Celery task)
curl -fsS -b "$JAR" \
  -H "Content-Type: application/json" \
  -H "X-CSRFToken: $CSRF" \
  -H "Referer: $TUBEARCHIVIST_URL/" \
  -X POST \
  -d '{"data":[{"channel_id":"https://www.youtube.com/@ExampleChannel","channel_subscribed":true}]}' \
  "$TUBEARCHIVIST_URL/api/channel/"

# 2. Wait for Celery (30-60s typical)
sleep 30

# 3. Check task result
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/task/by-name/" \
  | jq '.[] | select(.name == "subscribe_to") | {status, date_done}' | head -10

# 4. Confirm channel is now listed
curl -fsS -b "$JAR" "$TUBEARCHIVIST_URL/api/channel/" \
  | jq '.data[] | .channel_name'
```

### Workflow: fetch full OpenAPI schema for ad-hoc endpoint discovery

```bash
curl -fsS -b "$JAR" -H "Accept: application/yaml" \
  "$TUBEARCHIVIST_URL/api/schema/" > /tmp/ta-schema.yaml
grep -E "^  /api/" /tmp/ta-schema.yaml | sort
```
