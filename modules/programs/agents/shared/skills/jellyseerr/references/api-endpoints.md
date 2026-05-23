# Jellyseerr API Reference

**API Version:** v1
**Base URL:** `http://192.168.1.83:5055/api/v1`
**Authentication:** `X-Api-Key` header
**Upstream docs:** https://api-docs.overseerr.dev/ (Jellyseerr forks Overseerr;
the API surface matches)

## Authentication

Jellyseerr uses API key authentication. The key lives at
Settings → General → API Key. Send it on every request:

```bash
-H "X-Api-Key: <your_api_key>"
```

Some endpoints (creating requests, voting on issues) also require a logged-in
user session and ignore the service API key. The endpoints documented here are
the read/admin paths used by `scripts/jellyseerr.sh`.

## Quick Start

Credentials come from sops-nix and are exported into the shell by
`modules/programs/shell.nix`:

```bash
JELLYSEERR_URL=http://192.168.1.83:5055
JELLYSEERR_API_KEY=<api key from Jellyseerr Settings → General>
```

Sanity check:

```bash
curl -s "$JELLYSEERR_URL/api/v1/status" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

## Endpoints by Category

### System

#### GET /status

Get system status and version information.

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/status" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY"
```

**Example Response:**
```json
{
  "version": "2.5.0",
  "commitTag": "abcdef1",
  "updateAvailable": false,
  "commitsBehind": 0,
  "restartRequired": false
}
```

**Response Codes:**
- `200`: Success
- `401`: Unauthorized

---

### Requests

#### GET /request

Get media requests.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| take (query) | integer | No | Page size (default: 10) |
| skip (query) | integer | No | Offset for pagination |
| filter (query) | string | No | `all`, `pending`, `approved`, `declined`, `processing`, `available`, `unavailable` |
| sort (query) | string | No | `added` (default), `modified` |
| requestedBy (query) | integer | No | Filter by requester user ID |

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/request?take=50&sort=added&filter=pending" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

**Example Response (truncated):**
```json
{
  "pageInfo": { "pages": 1, "pageSize": 50, "results": 3, "page": 1 },
  "results": [
    {
      "id": 42,
      "status": 1,
      "type": "movie",
      "createdAt": "2026-05-19T01:23:00.000Z",
      "updatedAt": "2026-05-19T01:23:00.000Z",
      "media": {
        "id": 314,
        "mediaType": "movie",
        "tmdbId": 603,
        "status": 2
      },
      "requestedBy": {
        "id": 4,
        "username": "alice",
        "displayName": "Alice"
      }
    }
  ]
}
```

**Status enum:**
- `1` PENDING_APPROVAL
- `2` APPROVED
- `3` DECLINED

**Media status enum:**
- `1` UNKNOWN
- `2` PENDING
- `3` PROCESSING
- `4` PARTIALLY_AVAILABLE
- `5` AVAILABLE

**Response Codes:**
- `200`: Success
- `401`: Unauthorized

---

#### GET /request/count

Counts grouped by state. Useful for dashboards.

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/request/count" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY"
```

**Example Response:**
```json
{
  "total": 87,
  "movie": 51,
  "tv": 36,
  "pending": 2,
  "approved": 85,
  "declined": 0,
  "processing": 1,
  "available": 84
}
```

---

#### POST /request/{id}/approve

Approve a pending request. Triggers the linked Sonarr/Radarr to start
downloading.

**Example Request:**
```bash
curl -X POST "$JELLYSEERR_URL/api/v1/request/42/approve" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY"
```

**Response Codes:**
- `200`: Approved (returns updated request)
- `404`: Request not found
- `500`: Approval failed (often: no quality profile / root folder configured
  for the linked *arr)

---

#### POST /request/{id}/decline

Decline a pending request. Visible to the requester.

**Example Request:**
```bash
curl -X POST "$JELLYSEERR_URL/api/v1/request/42/decline" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY"
```

**Response Codes:**
- `200`: Declined
- `404`: Request not found

---

#### DELETE /request/{id}

Permanently remove a request. Does not delete media files from Jellyfin or the
*arrs.

**Example Request:**
```bash
curl -X DELETE "$JELLYSEERR_URL/api/v1/request/42" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY"
```

**Response Codes:**
- `204`: Deleted
- `404`: Request not found

---

### Search

#### GET /search

TMDB multi-search across movies and TV.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| query (query) | string | Yes | Search term |
| page (query) | integer | No | Page number (default: 1) |
| language (query) | string | No | ISO-639-1 (default: server pref) |

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/search?query=severance" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq '.results[0]'
```

**Example Response (single result):**
```json
{
  "id": 95396,
  "mediaType": "tv",
  "name": "Severance",
  "firstAirDate": "2022-02-18",
  "overview": "Mark leads a team of office workers...",
  "voteAverage": 8.4,
  "mediaInfo": {
    "id": 27,
    "status": 5,
    "tmdbId": 95396
  }
}
```

Notes:
- `mediaType` is `movie`, `tv`, or `person`.
- For movies the title field is `title` and date is `releaseDate`.
- For TV the title field is `name` and date is `firstAirDate`.
- `mediaInfo` is present only if Jellyseerr is already tracking the item.

**Response Codes:**
- `200`: Success (empty `results` array if no matches)

---

### Media

#### GET /media

Browse media tracked by Jellyseerr.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| take (query) | integer | No | Page size |
| skip (query) | integer | No | Offset |
| filter (query) | string | No | `all`, `available`, `partial`, `allavailable`, `processing`, `pending` |
| sort (query) | string | No | `added` (default), `modified`, `mediaAdded` |

**Example Request (recently added, available):**
```bash
curl -s "$JELLYSEERR_URL/api/v1/media?filter=available&sort=mediaAdded&take=50" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

**Response Codes:**
- `200`: Success

---

#### GET /media/{id}

Single media row by Jellyseerr internal `mediaId` (not TMDB id).

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/media/27" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY"
```

**Response Codes:**
- `200`: Success
- `404`: Not found

---

### Users

#### GET /user

List users. Requires the API key to belong to an admin (Jellyseerr default).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| take (query) | integer | No | Page size |
| skip (query) | integer | No | Offset |
| sort (query) | string | No | `created`, `updated`, `displayname`, `requests` |

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/user?take=100" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq '.results[] | {id, displayName, email, userType}'
```

**Response Codes:**
- `200`: Success
- `403`: Forbidden (key lacks admin permission)

---

### Issues

#### GET /issue

List user-reported issues against media.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| take (query) | integer | No | Page size |
| filter (query) | string | No | `open` (default), `closed`, `all` |
| sort (query) | string | No | `added`, `modified` |

**Example Request:**
```bash
curl -s "$JELLYSEERR_URL/api/v1/issue?take=50&filter=open" \
  -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq
```

**Issue type enum:**
- `1` VIDEO
- `2` AUDIO
- `3` SUBTITLE
- `4` OTHER

**Issue status enum:**
- `1` OPEN
- `2` RESOLVED

**Response Codes:**
- `200`: Success

---

## Pagination

List endpoints return:

```json
{
  "pageInfo": { "pages": 3, "pageSize": 50, "results": 137, "page": 1 },
  "results": [ ... ]
}
```

Pass `take` (page size) and `skip` (offset) to page through results.

## Calendar-style Overview

| Endpoint                       | Use it for                                              |
| ------------------------------ | ------------------------------------------------------- |
| `GET /status`                  | Sanity check; version + update info                     |
| `GET /request?filter=pending`  | Triage inbox                                            |
| `GET /request/count`           | Quick totals (movies/TV/pending/approved/declined/etc.) |
| `GET /search?query=…`          | "Is this on TMDB?" lookup before adding                 |
| `GET /media/{id}`              | "Is Jellyseerr already tracking this?"                  |
| `GET /media?filter=available`  | What's been added recently                              |
| `POST /request/{id}/approve`   | Approve and trigger download                            |
| `POST /request/{id}/decline`   | Decline visibly to requester                            |
| `DELETE /request/{id}`         | Drop a request without touching media files             |
| `GET /user`                    | Admin user roster                                       |
| `GET /issue?filter=open`       | User-reported playback / audio / subtitle problems      |

## Version History

| API Version | Doc Version | Date       | Changes               |
| ----------- | ----------- | ---------- | --------------------- |
| v1          | 1.0.0       | 2026-05-22 | Initial documentation |

## Additional Resources

- [Overseerr API docs (matches Jellyseerr)](https://api-docs.overseerr.dev/)
- [Jellyseerr GitHub](https://github.com/Fallenbagel/jellyseerr)
- [Jellyseerr docs](https://docs.jellyseerr.dev/)
