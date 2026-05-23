# SABnzbd API Reference

**API Version:** 4.5+
**Base URL:** `$SABNZBD_URL/api`
**Authentication:** API key via `apikey` query parameter
**Last Updated:** 2026-05-22

## Authentication

SABnzbd uses API key authentication via query string. Find your API key in
SABnzbd Config -> General -> Security.

```bash
"$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=<mode>"
```

There is no header-based auth path that works reliably across all modes;
prefer the query parameter.

## Quick Start

Credentials come from sops-nix and are exported into the shell by
`modules/programs/shell.nix`:

```bash
SABNZBD_URL=http://192.168.1.133:7777
SABNZBD_API_KEY=<api key from SABnzbd Config -> General -> Security>
```

Sanity check:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version" | jq
```

## API Format

All API requests follow this pattern:

```
/api?mode=<COMMAND>&apikey=<KEY>&output=json&<param1>=<value1>&<param2>=<value2>
```

Response format:

- Default is XML.
- Always pass `output=json` for JSON.

## Endpoints by Category

### Queue Management

#### mode=queue

Get current download queue status.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| start (query) | integer | No | Start position (pagination) |
| limit (query) | integer | No | Number of items to return |
| search (query) | string | No | Filter by filename substring |
| nzo_ids (query) | string | No | Comma-separated NZO IDs to filter to |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue"
```

**Example Response:**
```json
{
  "queue": {
    "status": "Downloading",
    "speed": "5.2 MB/s",
    "speedlimit": "0",
    "speedlimit_abs": "0",
    "paused": false,
    "noofslots_total": 3,
    "noofslots": 3,
    "timeleft": "0:15:32",
    "mb": "450.23",
    "mbleft": "78.45",
    "slots": [
      {
        "nzo_id": "SABnzbd_nzo_abc123",
        "filename": "Ubuntu.22.04.iso",
        "status": "Downloading",
        "mb": "150.50",
        "mbleft": "45.23",
        "percentage": "70",
        "cat": "software",
        "priority": "Normal"
      }
    ]
  }
}
```

---

#### mode=addurl

Add NZB by URL.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| name (query) | string | Yes | URL to NZB file or newznab link (URL-encode it) |
| nzbname (query) | string | No | Override displayed name |
| cat (query) | string | No | Category |
| priority (query) | integer | No | Priority (-100 to 2; default 0) |
| pp (query) | integer | No | Post-processing (0=None, 1=Repair, 2=Repair+Unpack, 3=+Delete) |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=addurl" \
  --data-urlencode "name=http://example.com/file.nzb" \
  --data-urlencode "cat=movies" \
  --data-urlencode "priority=1"
```

---

#### mode=addfile

Upload a local NZB file.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| nzbfile (multipart) | file | Yes | NZB file to upload |
| cat (query) | string | No | Category |
| priority (query) | integer | No | Priority |
| pp (query) | integer | No | Post-processing level |

**Example Request:**
```bash
curl -fsS -X POST \
  -F "apikey=$SABNZBD_API_KEY" \
  -F "output=json" \
  -F "mode=addfile" \
  -F "nzbfile=@/path/to/file.nzb" \
  -F "cat=movies" \
  "$SABNZBD_URL/api"
```

---

#### mode=pause

Pause the queue.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| value (query) | integer | No | Pause duration in minutes (0 = indefinite) |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=pause"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=pause&value=30"
```

---

#### mode=resume

Resume the queue.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=resume"
```

---

#### mode=queue&name=delete

Delete an item from the queue (or all items).

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| value (query) | string | Yes | NZO ID, comma-separated NZO IDs, or `all` |
| del_files (query) | integer | No | 1 = delete downloaded files too (default 0) |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=delete&value=SABnzbd_nzo_abc123"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=delete&value=all"
```

---

#### mode=queue&name=priority

Change a queue item's priority.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| value (query) | string | Yes | NZO ID |
| value2 (query) | integer | Yes | New priority (-2..2) |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=priority&value=SABnzbd_nzo_abc123&value2=2"
```

---

#### mode=queue&name=pause / name=resume

Pause or resume a single queue item.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=pause&value=SABnzbd_nzo_abc123"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=resume&value=SABnzbd_nzo_abc123"
```

---

### History

#### mode=history

Get download history.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| start (query) | integer | No | Start position |
| limit (query) | integer | No | Number of items (default: all) |
| category (query) | string | No | Filter by category |
| search (query) | string | No | Substring match |
| failed_only (query) | integer | No | 1 = only failed downloads |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&limit=20"
```

**Example Response:**
```json
{
  "history": {
    "total_size": "15.2 GB",
    "month_size": "5.4 GB",
    "week_size": "1.2 GB",
    "noofslots": 45,
    "slots": [
      {
        "nzo_id": "SABnzbd_nzo_xyz789",
        "name": "Ubuntu.22.04.iso",
        "status": "Completed",
        "category": "software",
        "bytes": 4500000000,
        "fail_message": "",
        "completed": 1706472000,
        "storage": "/downloads/complete/Ubuntu.22.04.iso"
      }
    ]
  }
}
```

---

#### mode=history&name=delete

Delete an item from history.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| value (query) | string | Yes | NZO ID or `all` |
| del_files (query) | integer | No | 1 = also delete files from disk |

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&name=delete&value=SABnzbd_nzo_xyz789"
```

---

#### mode=retry / mode=retry_all

Retry a single failed history item, or all failed items.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=retry&value=SABnzbd_nzo_xyz789"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=retry_all"
```

---

### Server Status

#### mode=server_stats

Get aggregate download statistics.

**Example Request:**
```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=server_stats"
```

**Example Response:**
```json
{
  "total": 1342177280000,
  "month": 48557981696,
  "week": 9126805504,
  "day": 1288490189,
  "servers": {
    "news.example.com": {
      "total": 1342177280000,
      "month": 48557981696,
      "week": 9126805504,
      "day": 1288490189,
      "daily": { "2026-05-21": 1288490189 }
    }
  }
}
```

---

#### mode=fullstatus

Get complete SABnzbd status. The whole payload is wrapped under `.status`.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=fullstatus" \
  | jq '.status | {version, uptime, paused, diskspace1_norm, have_warnings}'
```

---

#### mode=version

Get SABnzbd version (returns `{"version": "4.5.2"}` with `output=json`).

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
```

---

#### mode=warnings

List active warnings (and `&name=clear` to clear them).

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=warnings"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=warnings&name=clear"
```

---

### Configuration

#### mode=get_config

Read current configuration.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=get_config"
```

---

#### mode=set_config

Update a configuration value.

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| section (query) | string | Yes | Config section (e.g. `misc`) |
| keyword (query) | string | Yes | Setting name |
| value (query) | string | Yes | New value |

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=set_config&section=misc&keyword=bandwidth_max&value=10M"
```

---

#### mode=speedlimit

Set the active download speed limit. Accepts a percentage of the configured
max (e.g. `50`), an absolute value with suffix (`5M`, `2048K`), or `0` for
unlimited.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=5M"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=0"
```

---

### Categories

#### mode=get_cats

List configured categories.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=get_cats"
```

---

#### mode=change_cat

Reassign a queue item to a different category.

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=change_cat&value=SABnzbd_nzo_abc123&value2=movies"
```

---

## Priority Values

- `2` — Force (highest)
- `1` — High
- `0` — Normal (default)
- `-1` — Low
- `-2` — Paused
- `-3` — Duplicate

## Post-Processing Options

- `0` — None
- `1` — Repair
- `2` — Repair + Unpack
- `3` — Repair + Unpack + Delete source NZB

## Version History

| API Version | Doc Version | Date | Changes |
|-------------|-------------|------|---------|
| 4.5+ | 1.1.0 | 2026-05-22 | Adapted for sops-nix / query-param auth |
| 4.5+ | 1.0.0 | 2026-02-01 | Initial documentation |

## Additional Resources

- [Official API Documentation](https://sabnzbd.org/wiki/configuration/4.5/api)
- [GitHub Repository](https://github.com/sabnzbd/sabnzbd)
- [Configuration Guide](https://sabnzbd.org/wiki/configuration/4.5)
