# Prowlarr Quick Reference

Common operations for quick copy-paste usage.

## Setup

`PROWLARR_URL` and `PROWLARR_API_KEY` are exported into the shell by sops-nix
via `modules/programs/shell.nix`. No `source` step required — just use the
variables directly:

```bash
curl -s "$PROWLARR_URL/api/v1/system/status" -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## System

### Status

```bash
curl -s "$PROWLARR_URL/api/v1/system/status" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Health warnings

```bash
curl -s "$PROWLARR_URL/api/v1/health" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Indexers

### List all (summary)

```bash
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq '[.[] | {id, name, protocol, enable, priority}]'
```

### Get one indexer

```bash
curl -s "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Schemas (available indexer definitions)

```bash
curl -s "$PROWLARR_URL/api/v1/indexer/schema" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq '.[] | {implementationName, protocol}'
```

### Enable / disable

```bash
INDEXER_ID=1
ENABLE=false
indexer=$(curl -s "$PROWLARR_URL/api/v1/indexer/$INDEXER_ID" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq ".enable = $ENABLE")
curl -s -X PUT "$PROWLARR_URL/api/v1/indexer/$INDEXER_ID" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$indexer" | jq '{id, name, enable}'
```

### Test

```bash
INDEXER_ID=1
indexer=$(curl -s "$PROWLARR_URL/api/v1/indexer/$INDEXER_ID" \
  -H "X-Api-Key: $PROWLARR_API_KEY")
curl -i -X POST "$PROWLARR_URL/api/v1/indexer/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$indexer"
```

### Delete

```bash
curl -X DELETE "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

## Search

### Free-text across all indexers

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=ubuntu&type=search" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq '[.[] | {title, indexer, protocol, seeders, sizeMB: (.size / 1048576 | floor)}]'
```

### Torrents only

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=inception&type=search&indexerIds=-2" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Usenet only

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=inception&type=search&indexerIds=-1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### TV by TVDB ID

```bash
Q='{TvdbId:81189} {Season:1} {Episode:1}'
QE=$(jq -sRr @uri <<<"$Q")
curl -s "$PROWLARR_URL/api/v1/search?query=${QE}&type=tvsearch" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Movie by IMDB

```bash
QE=$(jq -sRr @uri <<<'{ImdbId:tt0111161}')
curl -s "$PROWLARR_URL/api/v1/search?query=${QE}&type=movie" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

### Specific indexers + category

```bash
curl -s "$PROWLARR_URL/api/v1/search?query=ubuntu&indexerIds=1,3&categories=4000" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Stats

```bash
curl -s "$PROWLARR_URL/api/v1/indexerstats" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq '.indexers | [.[] | {
    name: .indexerName,
    queries: .numberOfQueries,
    grabs: .numberOfGrabs,
    failedQueries: .numberOfFailedQueries,
    avgMs: .averageResponseTime
  }]'
```

## History

```bash
curl -s "$PROWLARR_URL/api/v1/history?page=1&pageSize=20&sortKey=date&sortDirection=descending" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq '.records[] | {date, eventType, indexerId, query: .data.query, results: .data.results, ok: .data.successful}'
```

## Applications

### List

```bash
curl -s "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq '[.[] | {id, name, implementation, syncLevel}]'
```

### Push indexers to all apps

```bash
curl -X POST "$PROWLARR_URL/api/v1/command" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "ApplicationIndexerSync"}' | jq
```

### Test an app

```bash
APP_ID=1
app=$(curl -s "$PROWLARR_URL/api/v1/applications/$APP_ID" \
  -H "X-Api-Key: $PROWLARR_API_KEY")
curl -i -X POST "$PROWLARR_URL/api/v1/applications/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$app"
```

## Tags

```bash
curl -s "$PROWLARR_URL/api/v1/tag" -H "X-Api-Key: $PROWLARR_API_KEY" | jq
curl -X POST "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"label": "public"}'
```

## Workflows

### Workflow: search and pick the best torrent

```bash
QUERY="ubuntu 24.04"
curl -s "$PROWLARR_URL/api/v1/search?query=$(jq -sRr @uri <<<"$QUERY")&type=search&indexerIds=-2" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq 'sort_by(-.seeders) | [.[] | {title, indexer, seeders, sizeMB: (.size / 1048576 | floor), downloadUrl}] | .[:10]'
```

### Workflow: test all indexers

```bash
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -c '.[]' | \
  while read -r indexer; do
    id=$(echo "$indexer" | jq -r '.id')
    name=$(echo "$indexer" | jq -r '.name')
    code=$(curl -sS -o /dev/null -w '%{http_code}' \
      -X POST -H "X-Api-Key: $PROWLARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$indexer" "$PROWLARR_URL/api/v1/indexer/test")
    echo "$id $name -> $code"
    sleep 1
  done
```

### Workflow: disable indexers with high failure rates

```bash
curl -s "$PROWLARR_URL/api/v1/indexerstats" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -r '.indexers[] | select(.numberOfFailedQueries > 5) | .indexerId' | \
  while read -r id; do
    echo "disabling indexer $id"
    curl -s "$PROWLARR_URL/api/v1/indexer/$id" \
      -H "X-Api-Key: $PROWLARR_API_KEY" | \
      jq '.enable = false' | \
      curl -s -X PUT "$PROWLARR_URL/api/v1/indexer/$id" \
        -H "X-Api-Key: $PROWLARR_API_KEY" \
        -H "Content-Type: application/json" \
        -d @- > /dev/null
  done
```

### Workflow: per-indexer search comparison

```bash
QUERY="ubuntu"
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | \
  jq -r '.[] | select(.enable) | "\(.id)\t\(.name)"' | \
  while IFS=$'\t' read -r id name; do
    count=$(curl -s "$PROWLARR_URL/api/v1/search?query=${QUERY}&indexerIds=${id}" \
      -H "X-Api-Key: $PROWLARR_API_KEY" | jq 'length')
    printf '%-30s %s\n' "$name" "$count results"
  done
```
