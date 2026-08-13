# Jellyfin API Reference

**Base URL:** `$JELLYFIN_URL` (e.g. `http://192.168.1.21:8096`)
**Authentication:** `X-Emby-Token` header (Jellyfin reuses the Emby header)
**Spec:** <https://api.jellyfin.org/>

## Authentication

Generate an API key in Dashboard → API Keys, then send it on every request:

```bash
-H "X-Emby-Token: $JELLYFIN_API_KEY"
```

Credentials come from sops-nix and are exported into the shell by
`modules/programs/shell.nix`:

```bash
JELLYFIN_URL=http://192.168.1.21:8096
JELLYFIN_API_KEY=<api key from Dashboard → API Keys>
```

Sanity check:

```bash
curl -s "$JELLYFIN_URL/System/Info" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

## Endpoints by Category

### System

#### GET /System/Info

Server identity, version, and OS info.

```bash
curl -s "$JELLYFIN_URL/System/Info" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

Response (truncated):

```json
{
  "ServerName": "jellyfin",
  "Version": "10.11.8",
  "Id": "2391bef579184058abbcc82ea133a9d5",
  "ProductName": "Jellyfin Server",
  "LocalAddress": "http://192.168.1.21:8096"
}
```

#### GET /System/Info/Public

Same shape as `/System/Info` but does not require auth — useful for a
reachability probe.

---

### Users

#### GET /Users

All users on the server.

```bash
curl -s "$JELLYFIN_URL/Users" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

Response (truncated):

```json
[
  {
    "Name": "jellyfin",
    "Id": "eb6b5542c8d54bcfabf54a0a1460b0cd",
    "LastActivityDate": "2026-05-23T02:08:19Z",
    "Policy": { "IsAdministrator": true, "IsDisabled": false }
  }
]
```

#### GET /Users/{userId}

Single user. The wrapper's `recently-added` and `item-search` commands need a
user id; many `/Items` endpoints are user-scoped.

---

### Libraries

#### GET /Library/VirtualFolders

All libraries (called "virtual folders" in the API) with their type and
filesystem locations.

```bash
curl -s "$JELLYFIN_URL/Library/VirtualFolders" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

#### POST /Library/Refresh

Trigger a full library scan. Async — no body required.

---

### Items

#### GET /Items/Counts

Library totals.

```bash
curl -s "$JELLYFIN_URL/Items/Counts" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

Response:

```json
{
  "MovieCount": 86,
  "SeriesCount": 64,
  "EpisodeCount": 3481,
  "ArtistCount": 0,
  "AlbumCount": 0,
  "SongCount": 0,
  "BookCount": 0,
  "ItemCount": 0
}
```

#### GET /Users/{userId}/Items/Latest

Recently added items, scoped to a user (respects library permissions).

| Param         | Type   | Notes                                          |
| ------------- | ------ | ---------------------------------------------- |
| Limit         | int    | Number of items (default 20)                   |
| ParentId      | string | Restrict to one library                        |
| IncludeItemTypes | csv | e.g. `Movie,Episode`                           |

```bash
curl -s "$JELLYFIN_URL/Users/$USER_ID/Items/Latest?Limit=10" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

#### GET /Users/{userId}/Items

User-scoped item query. Supports search, recursion, type filters, sorting.

| Param            | Type   | Notes                                                  |
| ---------------- | ------ | ------------------------------------------------------ |
| searchTerm       | string | Free-text search                                       |
| Recursive        | bool   | Required to search the whole library                   |
| IncludeItemTypes | csv    | e.g. `Movie,Series,Episode`                            |
| Limit            | int    | Cap results                                            |
| ParentId         | string | Restrict to one library                                |
| SortBy           | string | e.g. `DateCreated,SortName`                            |
| SortOrder        | string | `Ascending` or `Descending`                            |

```bash
curl -s "$JELLYFIN_URL/Users/$USER_ID/Items?searchTerm=severance&Recursive=true&IncludeItemTypes=Movie,Series,Episode&Limit=25" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

Response shape: `{ "Items": [...], "TotalRecordCount": N }`.

---

### Sessions

#### GET /Sessions

Every connected session (playing or idle).

```bash
curl -s "$JELLYFIN_URL/Sessions" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

Useful fields:

- `UserName`, `Client`, `DeviceName`, `ApplicationVersion`
- `NowPlayingItem` (object or absent) — `Name`, `Type`, `SeriesName`,
  `ParentIndexNumber` (season), `IndexNumber` (episode), `RunTimeTicks`
- `PlayState` — `PositionTicks`, `IsPaused`, `PlayMethod`
  (`DirectPlay` | `DirectStream` | `Transcode`)

To filter to currently-playing in jq:

```bash
jq '[.[] | select(.NowPlayingItem != null)]'
```

Ticks are 10,000,000 per second (100 ns units). Seconds = `ticks / 10000000`.

#### POST /Sessions/{sessionId}/Playing/Stop

Stop playback on a session. Mutation — confirm first.

---

### Scheduled Tasks

#### GET /ScheduledTasks

All scheduled tasks with state and last execution result.

```bash
curl -s "$JELLYFIN_URL/ScheduledTasks" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" | jq
```

Useful fields per task: `Id`, `Name`, `State` (`Idle` | `Running`),
`LastExecutionResult.Status`, `LastExecutionResult.EndTimeUtc`, `Category`,
`Triggers`.

#### POST /ScheduledTasks/Running/{taskId}

Kick off a task. No body. Returns 204 on success.

```bash
curl -X POST "$JELLYFIN_URL/ScheduledTasks/Running/$TASK_ID" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY"
```

#### DELETE /ScheduledTasks/Running/{taskId}

Stop a running task.

---

### Plugins

#### GET /Plugins

Installed plugins with versions and statuses.

---

## Pagination

`GET /Users/{userId}/Items` and similar endpoints accept:

- `StartIndex` — offset
- `Limit` — page size

The response includes `TotalRecordCount` so you can paginate cleanly.

## Ticks ↔ Seconds Helpers

```bash
# Position in seconds
jq '.PlayState.PositionTicks / 10000000'

# Remaining seconds
jq '(.NowPlayingItem.RunTimeTicks - .PlayState.PositionTicks) / 10000000'
```

## Additional Resources

- Official spec: <https://api.jellyfin.org/>
- OpenAPI JSON: <https://repo.jellyfin.org/files/openapi/stable/jellyfin-openapi-stable.json>
- Source: <https://github.com/jellyfin/jellyfin>
