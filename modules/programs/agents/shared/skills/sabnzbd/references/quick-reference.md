# SABnzbd Quick Reference

Common operations for quick copy-paste usage.

## Setup

`SABNZBD_URL` and `SABNZBD_API_KEY` are exported into the shell by sops-nix
via `modules/programs/shell.nix`. No `source` step required — just use the
variables directly:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version" | jq
```

SABnzbd authenticates via the `apikey` query parameter; there is no
`X-Api-Key` header path.

## Queue Management

### Get Queue Status

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" | jq
```

### Queue with Pagination

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&start=0&limit=10" | jq
```

### Compact Queue View

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
  | jq '.queue.slots[] | {filename, status, percentage, mbleft, priority}'
```

### Pause / Resume Queue

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=pause"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=pause&value=30"   # 30 minutes
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=resume"
```

### Delete Queue Item

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=delete&value=SABnzbd_nzo_abc123"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=delete&value=SABnzbd_nzo_abc123&del_files=1"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=delete&value=all"
```

## Adding NZBs

### Add by URL

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=addurl" \
  --data-urlencode "name=http://example.com/file.nzb"

curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=addurl" \
  --data-urlencode "name=http://example.com/file.nzb" \
  --data-urlencode "cat=movies" \
  --data-urlencode "priority=1"
```

### Add by File Upload

```bash
curl -fsS -X POST \
  -F "apikey=$SABNZBD_API_KEY" \
  -F "output=json" \
  -F "mode=addfile" \
  -F "nzbfile=@/path/to/file.nzb" \
  -F "cat=tv" \
  "$SABNZBD_URL/api"
```

### Priority Levels

- `2` — Force (highest)
- `1` — High
- `0` — Normal (default)
- `-1` — Low
- `-2` — Paused
- `-3` — Duplicate

### Post-Processing Levels

- `0` — None
- `1` — Repair
- `2` — Repair + Unpack
- `3` — Repair + Unpack + Delete

## Speed Control

### Set Download Speed Limit

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=5M"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=50"   # 50% of max
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=0"    # unlimited
```

### Show Current Speed

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
  | jq '.queue | {speed, speedlimit, speedlimit_abs}'
```

## History

### Get Download History

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history" | jq
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&limit=20" | jq
```

### Failed Downloads Only

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&failed_only=1" \
  | jq '.history.slots[] | {name, status, fail_message}'
```

### Filter History by Category

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&category=movies" | jq
```

### Delete History Item

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&name=delete&value=SABnzbd_nzo_xyz789"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&name=delete&value=all"
```

### Retry Failed

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=retry&value=SABnzbd_nzo_xyz789"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=retry_all"
```

## Categories

### List Categories

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=get_cats" | jq '.categories[]'
```

### Change Queue Item Category

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=change_cat&value=SABnzbd_nzo_abc123&value2=movies"
```

## Priority Management

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=priority&value=SABnzbd_nzo_abc123&value2=1"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=priority&value=SABnzbd_nzo_abc123&value2=2"
```

## Status & Information

### SABnzbd Version

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
```

### Full Status

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=fullstatus" \
  | jq '.status | {version, uptime, paused, diskspace1_norm, have_warnings}'
```

### Server Statistics

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=server_stats" \
  | jq '{total, month, week, day}'
```

### Warnings

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=warnings"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=warnings&name=clear"
```

### Get Configuration

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=get_config" | jq
```

## Workflows

### Workflow: Add and Monitor an NZB

1. **Add NZB by URL:**
   ```bash
   curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=addurl" \
     --data-urlencode "name=http://indexer.com/get.php?guid=xyz" \
     --data-urlencode "cat=movies" \
     --data-urlencode "priority=1" | jq '.nzo_ids[0]'
   ```

2. **Monitor queue:**
   ```bash
   curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
     | jq '.queue.slots[] | {filename, status, percentage, timeleft}'
   ```

3. **Check history after completion:**
   ```bash
   curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&limit=1" \
     | jq '.history.slots[0] | {name, status, storage}'
   ```

### Workflow: Batch Add Multiple NZBs

```bash
for url in \
  "http://indexer.com/nzb1.nzb" \
  "http://indexer.com/nzb2.nzb" \
  "http://indexer.com/nzb3.nzb"; do
  curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=addurl" \
    --data-urlencode "name=$url" \
    --data-urlencode "cat=tv" \
    --data-urlencode "priority=0"
  sleep 1
done
```

### Workflow: Clean Up Failed Downloads

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&failed_only=1" \
  | jq -r '.history.slots[].nzo_id' \
  | while read -r nzo_id; do
      echo "Deleting failed download: $nzo_id"
      curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&name=delete&value=$nzo_id"
    done
```

### Workflow: Throttle Downloads During Peak Hours

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=2M"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=0"
```

## One-Liners

### Active Downloads

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
  | jq -r '.queue.slots[] | "\(.filename) - \(.percentage)% - \(.timeleft) remaining"'
```

### Count Queue Items by Status

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
  | jq '.queue.slots | group_by(.status) | map({status: .[0].status, count: length})'
```

### Download Stats Summary

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=server_stats" \
  | jq '{today: .day, this_week: .week, this_month: .month, all_time: .total}'
```

### Recently Completed Downloads

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&limit=5" \
  | jq -r '.history.slots[] | "\(.name) - \(.status) - \(.storage)"'
```
