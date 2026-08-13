# Prowlarr API Reference

**API Version:** v1
**Base URL:** `$PROWLARR_URL/api/v1`
**Authentication:** `X-Api-Key` header

## Authentication

Prowlarr uses API key authentication. Find your API key in
Settings → General → Security.

```bash
-H "X-Api-Key: <your_api_key>"
```

## Quick Start

Credentials come from sops-nix and are exported into the shell by
`modules/programs/shell.nix`:

```bash
PROWLARR_URL=http://192.168.1.192:9696
PROWLARR_API_KEY=<api key from Prowlarr Settings → General → Security>
```

Sanity check:

```bash
curl -s "$PROWLARR_URL/api/v1/system/status" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

## Endpoints by Category

### System

#### GET /system/status

Get system status and version information.

**Example Request:**
```bash
curl -s "$PROWLARR_URL/api/v1/system/status" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Selected response fields:**
- `version`, `buildTime`
- `appName`, `instanceName`, `branch`
- `runtimeVersion`, `osName`, `osVersion`
- `isLinux`, `isProduction`

**Response Codes:**
- `200`: Success
- `401`: Unauthorized

---

#### GET /health

Get active health warnings.

**Example Request:**
```bash
curl -s "$PROWLARR_URL/api/v1/health" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

Each entry has `source`, `type` (`warning` | `error`), `message`, `wikiUrl`.

---

### Indexers

#### GET /indexer

Get all configured indexers.

**Selected response fields:** `id`, `name`, `protocol` (`torrent` | `usenet`),
`enable`, `priority`, `supportsRss`, `supportsSearch`, `capabilities`,
`implementation`, `implementationName`, `configContract`.

```bash
curl -s "$PROWLARR_URL/api/v1/indexer" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

---

#### GET /indexer/{id}

Get a specific indexer.

```bash
curl -s "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Response Codes:** `200`, `404`.

---

#### GET /indexer/schema

Get available indexer definitions (use this before adding a new one to find
valid `implementation` / `configContract` values).

```bash
curl -s "$PROWLARR_URL/api/v1/indexer/schema" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.[] | {implementationName, protocol}'
```

---

#### PUT /indexer/{id}

Update an indexer. Send the full indexer object back (round-trip the result of
`GET /indexer/{id}` with modifications).

```bash
curl -X PUT "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(curl -s "$PROWLARR_URL/api/v1/indexer/1" \
        -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.enable = false')"
```

**Response Codes:** `202`, `404`.

---

#### DELETE /indexer/{id}

Delete an indexer.

```bash
curl -X DELETE "$PROWLARR_URL/api/v1/indexer/1" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Response Codes:** `200`, `404`.

---

#### POST /indexer/test

Test an indexer's current configuration. Body is the full indexer object.

```bash
curl -X POST "$PROWLARR_URL/api/v1/indexer/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(curl -s "$PROWLARR_URL/api/v1/indexer/1" \
        -H "X-Api-Key: $PROWLARR_API_KEY")"
```

**Response Codes:** `200` (passed), `400` (failed, body has error list).

---

### Search

#### GET /search

Search across enabled indexers.

| Parameter | Type | Notes |
|-----------|------|-------|
| `query` | string | URL-encoded search term |
| `type` | string | `search` (default), `tvsearch`, `movie`, `music`, `book` |
| `categories` | string | Comma-separated Newznab categories |
| `indexerIds` | string | Comma-separated indexer IDs. `-1` = all usenet, `-2` = all torrent |
| `limit` | int | Max results per indexer |
| `offset` | int | Pagination offset |

**Free-text search:**
```bash
curl -s "$PROWLARR_URL/api/v1/search?query=ubuntu&type=search" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**TV search via TVDB ID** (uses Prowlarr's structured query syntax):
```bash
curl -s "$PROWLARR_URL/api/v1/search?query=%7BTvdbId%3A81189%7D%20%7BSeason%3A1%7D%20%7BEpisode%3A1%7D&type=tvsearch" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Movie search via IMDB ID:**
```bash
curl -s "$PROWLARR_URL/api/v1/search?query=%7BImdbId%3Att0111161%7D&type=movie" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

**Selected response fields per release:** `guid`, `indexerId`, `indexer`,
`title`, `publishDate`, `size`, `seeders`, `leechers`, `grabs`, `categories`,
`downloadUrl`, `infoUrl`, `protocol`, `indexerFlags`.

**Response Codes:** `200` (empty array if no results).

---

### Applications

#### GET /applications

List connected applications (Sonarr, Radarr, Lidarr, Readarr).

**Selected fields:** `id`, `name`, `implementation`, `configContract`,
`syncLevel`, `tags`, `fields[]` (config like `baseUrl`, `apiKey`,
`syncCategories`).

```bash
curl -s "$PROWLARR_URL/api/v1/applications" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

---

#### POST /applications/test

Test an application's connection. Body is the application object.

```bash
curl -X POST "$PROWLARR_URL/api/v1/applications/test" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(curl -s "$PROWLARR_URL/api/v1/applications/1" \
        -H "X-Api-Key: $PROWLARR_API_KEY")"
```

---

### Commands

#### POST /command

Queue a Prowlarr command.

**Useful command names:**
- `ApplicationIndexerSync` — push indexers to all connected apps
- `ApplicationCheckUpdate` — refresh app metadata
- `IndexerRssSync` — RSS sweep
- `RefreshIndexer` — refresh a single indexer (`indexerId` in body)

```bash
curl -X POST "$PROWLARR_URL/api/v1/command" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "ApplicationIndexerSync"}'
```

Returns a command record with `id`, `status` (`queued` / `started` /
`completed` / `failed`), `queued`, `started`, `ended`.

#### GET /command/{id}

Poll the status of a queued command.

```bash
curl -s "$PROWLARR_URL/api/v1/command/42" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq '.status'
```

---

### History

#### GET /history

Paginated indexer history (queries, grabs, failures).

| Parameter | Type | Notes |
|-----------|------|-------|
| `page` | int | 1-indexed |
| `pageSize` | int | items per page |
| `sortKey` | string | usually `date` |
| `sortDirection` | string | `ascending` or `descending` |
| `indexerId` | int | filter by indexer |
| `eventType` | int | `1`=grabbed, `2`=indexerQuery, `3`=indexerRss, `4`=indexerAuth, `5`=indexerUpdate |

```bash
curl -s "$PROWLARR_URL/api/v1/history?page=1&pageSize=20&sortKey=date&sortDirection=descending" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

Each record has `data.query`, `data.queryType`, `data.successful`,
`data.results`, `data.elapsedTime`.

---

### Stats

#### GET /indexerstats

Per-indexer usage. Optional `startDate` / `endDate` (ISO 8601) bound the
window.

```bash
curl -s "$PROWLARR_URL/api/v1/indexerstats" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

**Per-indexer fields:** `indexerId`, `indexerName`, `averageResponseTime`,
`numberOfQueries`, `numberOfGrabs`, `numberOfRssQueries`, `numberOfFailedQueries`,
`numberOfFailedGrabs`, `numberOfFailedRssQueries`.

---

### Download Clients

#### GET /downloadclient

List configured download clients (Prowlarr uses these only for the manual
download button in its UI; Sonarr/Radarr have their own).

```bash
curl -s "$PROWLARR_URL/api/v1/downloadclient" \
  -H "X-Api-Key: $PROWLARR_API_KEY" | jq
```

---

### Tags

#### GET /tag

```bash
curl -s "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY"
```

#### POST /tag

```bash
curl -X POST "$PROWLARR_URL/api/v1/tag" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"label": "public-trackers"}'
```

---

## Search Types

| `type` | Use |
|--------|-----|
| `search` | Generic free-text |
| `tvsearch` | TV — supports `{TvdbId:N}` `{Season:N}` `{Episode:N}` tokens |
| `movie` | Movies — supports `{ImdbId:tt...}` `{TmdbId:N}` |
| `music` | Music — `{ArtistId:N}` `{AlbumId:N}` |
| `book` | Books |

## Categories (Newznab/Torznab)

| Range | Category |
|-------|----------|
| 1000-1999 | Console |
| 2000-2999 | Movies (2040 HD, 2045 UHD, 2050 BluRay) |
| 3000-3999 | Audio |
| 4000-4999 | PC |
| 5000-5999 | TV (5040 HD, 5045 UHD) |
| 6000-6999 | XXX |
| 7000-7999 | Books |
| 8000-8999 | Other |

Pass comma-separated to `categories=`, e.g. `categories=2040,2045`.

## Sync Levels (Applications)

| Value | Behavior |
|-------|----------|
| `disabled` | Do not sync |
| `addOnly` | Only push new indexers |
| `fullSync` | Add + update + remove |

## Pagination

List endpoints support `page`, `pageSize`, `sortKey`, `sortDirection`.

## Additional Resources

- [Official Wiki](https://wiki.servarr.com/prowlarr)
- [GitHub](https://github.com/Prowlarr/Prowlarr)
- [Supported Indexers](https://wiki.servarr.com/prowlarr/supported)
- [Supported Applications](https://wiki.servarr.com/prowlarr/supported-applications)
