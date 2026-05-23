# BookLore API Reference

**API Version:** v1
**Base URL:** `${BOOKLORE_URL}/api/v1` (e.g. `http://192.168.1.7:8080/api/v1`)
**Authentication:** JWT bearer token via login
**Deployed instance reports:** `version: "development"` (see notes below)
**Last Updated:** 2026-05-22

## Important caveat: deployed vs upstream

This document describes endpoints that have been **verified to return HTTP
200** on the deployed instance (`development` build at
`http://192.168.1.7:8080`). The upstream BookLore project's `main` branch
likely has more endpoints (refresh, cover images, downloads, edits, OPDS
feeds, etc.), but those are **not all present here**.

If you need an endpoint that isn't listed below, verify against the running
instance first — see the controller-inspection recipe in
`troubleshooting.md`. Some commonly-assumed paths return 404 on this
deployment:

- `GET /api/v1/library` (singular) — 404; use `/libraries` (plural)
- `GET /api/v1/shelf` (singular) — 404; use `/shelves`
- `GET /api/v1/healthcheck` — 404; use `/version`

## Authentication

BookLore has no API-key auth. Clients log in with username/password and
receive a JWT access token (plus a refresh token). The access token is sent
on subsequent requests as `Authorization: Bearer <token>`.

### POST /auth/login

Log in. Returns access and refresh tokens.

**Body:**
```json
{"username": "<user>", "password": "<pass>"}
```

**Example Request:**
```bash
curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"username\":\"$BOOKLORE_USERNAME\",\"password\":\"$BOOKLORE_PASSWORD\"}" \
  "$BOOKLORE_URL/api/v1/auth/login"
```

**Example Response:**
```json
{
  "accessToken": "eyJhbGciOi...",
  "refreshToken": "eyJhbGciOi...",
  "isDefaultPassword": false
}
```

**Response Codes:**
- `200`: Success
- `401`: Bad credentials

### Using the token

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/users/me"
```

### POST /auth/refresh (upstream — may not exist on this deployment)

Upstream main typically exposes a refresh endpoint that takes the refresh
token and returns a fresh access token. **Verify it exists on this instance
before relying on it.** The wrapper script side-steps the question by
logging in fresh on every invocation.

```bash
# Hypothetical — confirm against your build:
curl -fsS -X POST -H "Content-Type: application/json" \
  -d "{\"refreshToken\":\"$REFRESH\"}" \
  "$BOOKLORE_URL/api/v1/auth/refresh"
```

## Verified read endpoints

### GET /version

Get app version info.

**Example Request:**
```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/version"
```

**Example Response:**
```json
{
  "current": "development",
  "latest": "v0.x.y"
}
```

**Response Codes:**
- `200`: Success

---

### GET /users/me

Get the logged-in user, including permissions.

**Example Request:**
```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/users/me"
```

**Example Response (shape):**
```json
{
  "id": 1,
  "username": "michael",
  "email": "michael@example.com",
  "permissions": {
    "admin": true,
    "canUpload": true,
    "canDownload": true,
    "...": "..."
  }
}
```

**Response Codes:**
- `200`: Success
- `401`: Missing/expired token

---

### GET /libraries

List libraries.

**Example Request:**
```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/libraries"
```

**Example Response (shape):**
```json
[
  {
    "id": 1,
    "name": "Books",
    "paths": [
      {"id": 11, "path": "/data/books"}
    ]
  },
  {
    "id": 2,
    "name": "Audiobooks",
    "paths": [
      {"id": 21, "path": "/data/audiobooks"}
    ]
  }
]
```

**Response Codes:**
- `200`: Success

---

### GET /books

Return **all** books as a flat array (no pagination envelope on this
deployment). For large libraries, slice client-side with jq.

**Example Request:**
```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq '.[:10] | .[] | {id, title, authors, libraryId}'
```

**Example Response (shape):**
```json
[
  {
    "id": 142,
    "title": null,
    "authors": null,
    "libraryId": 1,
    "metadata": {
      "title": "Project Hail Mary",
      "authors": ["Andy Weir"],
      "publishedDate": "2021-05-04",
      "...": "..."
    }
  }
]
```

**Response Codes:**
- `200`: Success

**Quirk:** on this deployment the top-level `title` and `authors` are
frequently `null`; the real values live under `metadata.title` and
`metadata.authors`. The wrapper script falls back to metadata when the
top-level field is null. When writing your own queries, do the same:
```bash
... | jq '.[] | {title: (.title // .metadata.title)}'
```

**Search note:** there is no confirmed server-side `?q=` parameter on this
deployment. The wrapper script's `search` sub-command fetches `/books` and
filters titles in jq (checking both top-level and metadata title).

---

### GET /books/{id}

Fetch a single book.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| id (path) | integer | Yes | Book ID |

**Example Request:**
```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books/142"
```

**Response Codes:**
- `200`: Success
- `404`: Not found

---

### GET /shelves

List the current user's shelves.

**Example Request:**
```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/shelves"
```

**Response Codes:**
- `200`: Success

---

## Upstream-only / unverified endpoints

These appear in upstream BookLore docs/source but were **not verified** on
the deployed instance. Confirm before relying on them.

- `POST /api/v1/auth/refresh` — refresh access token
- `GET /api/v1/books/{id}/cover` — cover image
- `GET /api/v1/books/{id}/download` — file download
- Bulk upload, edit, delete endpoints
- OPDS feeds

To check what's actually compiled into the running JAR, use the
controller-inspection recipe in `troubleshooting.md`.

## Pagination

`/api/v1/books` on this deployment returns a flat array (no `page`/`size`).
Slice client-side with jq:

```bash
curl -fsS -H "Authorization: Bearer $TOKEN" "$BOOKLORE_URL/api/v1/books" \
  | jq '.[:50]'
```

## Version History

| API Version | Doc Version | Date       | Changes                                  |
|-------------|-------------|------------|------------------------------------------|
| v1          | 1.0.0       | 2026-05-22 | Initial doc — verified read endpoints    |

## Additional Resources

- [BookLore GitHub](https://github.com/booklore-app/booklore)
- Running instance: `http://192.168.1.7:8080`
