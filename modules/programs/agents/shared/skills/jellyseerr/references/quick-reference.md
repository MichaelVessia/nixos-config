# Jellyseerr Quick Reference

Common operations for quick copy-paste usage.

## Setup

`JELLYSEERR_URL` and `JELLYSEERR_API_KEY` are exported into the shell by
sops-nix via `modules/programs/shell.nix`. No `source` step required — just
use the variables directly:

```bash
curl -s "$JELLYSEERR_URL/api/v1/status" -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

## System Information

### Get Status

```bash
curl -s "$JELLYSEERR_URL/api/v1/status" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

## Requests

### List Pending Requests

```bash
curl -s "$JELLYSEERR_URL/api/v1/request?take=50&sort=added&filter=pending" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq '.results[] | {id, type, requestedBy: .requestedBy.displayName, tmdbId: .media.tmdbId, status, mediaStatus: .media.status}'
```

### List All Requests (Any State)

```bash
curl -s "$JELLYSEERR_URL/api/v1/request?take=50&sort=added&filter=all" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

### Request Counts

```bash
curl -s "$JELLYSEERR_URL/api/v1/request/count" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

### Approve a Request

```bash
curl -X POST "$JELLYSEERR_URL/api/v1/request/42/approve" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

### Decline a Request

```bash
curl -X POST "$JELLYSEERR_URL/api/v1/request/42/decline" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

### Delete a Request

```bash
curl -X DELETE "$JELLYSEERR_URL/api/v1/request/42" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" -o /dev/null -w "%{http_code}\n"
```

## Search

### TMDB Multi-Search

```bash
QUERY="severance"
curl -s "$JELLYSEERR_URL/api/v1/search?query=$(jq -sRr @uri <<<"$QUERY")" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq '.results[:10] | .[] | {mediaType, id, title: (.title // .name), date: (.releaseDate // .firstAirDate), tracked: (.mediaInfo != null)}'
```

## Media

### Recently Added (Available)

```bash
curl -s "$JELLYSEERR_URL/api/v1/media?filter=available&sort=mediaAdded&take=50" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq '.results[] | {id, mediaType, tmdbId, status, mediaAdded}'
```

### Single Media Row

```bash
curl -s "$JELLYSEERR_URL/api/v1/media/27" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

## Users (admin)

### List Users

```bash
curl -s "$JELLYSEERR_URL/api/v1/user?take=100" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq '.results[] | {id, displayName, email, userType, permissions}'
```

## Issues

### Open Issues

```bash
curl -s "$JELLYSEERR_URL/api/v1/issue?take=50&filter=open" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq '.results[] | {id, issueType, status, createdBy: .createdBy.displayName, mediaId: .media.id, tmdbId: .media.tmdbId}'
```

## Workflows

### Workflow: Triage and Approve

1. **List pending:**
   ```bash
   curl -s "$JELLYSEERR_URL/api/v1/request?take=50&sort=added&filter=pending" \
     -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
     jq '.results[] | {id, type, tmdbId: .media.tmdbId, by: .requestedBy.displayName}'
   ```
2. **Confirm with user, then approve:**
   ```bash
   curl -X POST "$JELLYSEERR_URL/api/v1/request/42/approve" \
     -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
   ```
3. **Follow up in the linked *arr:** see the `sonarr`/`radarr` skills for
   queue and history.

### Workflow: Decline Stale Requests

```bash
# Decline every pending request older than 90 days (dry run prints the IDs)
cutoff=$(date -u -d '90 days ago' +%s)
curl -s "$JELLYSEERR_URL/api/v1/request?take=100&filter=pending&sort=added" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq -r --argjson cutoff "$cutoff" '
    .results[]
    | select((.createdAt | fromdateiso8601) < $cutoff)
    | .id'
```

Pipe to a confirming loop only after a human reviews the list.

### Workflow: "Is this already tracked?"

```bash
QUERY="severance"
curl -s "$JELLYSEERR_URL/api/v1/search?query=$(jq -sRr @uri <<<"$QUERY")" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | \
  jq '.results[] | select(.mediaInfo != null) | {title: (.title // .name), mediaId: .mediaInfo.id, status: .mediaInfo.status}'
```
