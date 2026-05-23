# AdGuard Home API Reference

**Tested against:** AdGuard Home v0.107.67
**Base URL:** `http://<host>/control`
**Authentication:** HTTP Basic auth (`-u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD"`)
**Last Verified:** 2026-05-23

Sources:

- Wiki: https://github.com/AdguardTeam/AdGuardHome/wiki/API
- OpenAPI spec: https://github.com/AdguardTeam/AdGuardHome/blob/master/openapi/openapi.yaml

Field lists below reflect what v0.107.67 actually returns on the live instance.
Newer versions may add fields without breaking the ones documented here.

## Authentication

All endpoints require HTTP basic auth. Username/password are configured in
AdGuardHome's `AdGuardHome.yaml` (`users:` list). Passwords are stored bcrypt-
hashed — see `troubleshooting.md` for rotation.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/status"
```

## Endpoints used by the wrapper

### GET /control/status

System status and version. Sanity check.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" "$ADGUARD_URL/control/status"
```

Response (verified v0.107.67):

```json
{
  "version": "v0.107.67",
  "running": true,
  "protection_enabled": true,
  "protection_disabled_duration": 0,
  "dns_addresses": ["127.0.0.1", "::1", "192.168.1.109"],
  "dns_port": 53,
  "http_port": 80,
  "dhcp_available": true,
  "language": "en"
}
```

### GET /control/stats

Aggregate query stats over the configured stats interval. Top lists are arrays
of single-key objects: `[{"<domain>": <count>}, ...]`.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" "$ADGUARD_URL/control/stats"
```

Top-level fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `num_dns_queries` | int | total DNS queries in interval |
| `num_blocked_filtering` | int | blocked by filter lists |
| `num_replaced_safebrowsing` | int | replaced by safebrowsing |
| `num_replaced_safesearch` | int | replaced by safe search |
| `num_replaced_parental` | int | replaced by parental control |
| `avg_processing_time` | float (seconds) | mean per-query time |
| `time_units` | string | `"hours"` or `"days"` |
| `dns_queries` | int[] | per-time-unit bucket totals |
| `blocked_filtering` | int[] | per-time-unit blocked totals |
| `top_queried_domains` | `[{"<domain>": int}, ...]` | |
| `top_blocked_domains` | `[{"<domain>": int}, ...]` | |
| `top_clients` | `[{"<ip>": int}, ...]` | |
| `top_upstreams_responses` | `[{"<upstream>": int}, ...]` | |
| `top_upstreams_avg_time` | `[{"<upstream>": float}, ...]` | |

### GET /control/stats_info

Retention interval (in days) used for `/control/stats`.

```json
{ "interval": 1 }
```

### GET /control/querylog

Recent DNS queries. Default returns latest entries; the wrapper uses
`?limit=<n>` and `?search=<substr>`.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/querylog?limit=50"

curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/querylog?search=microsoft&limit=200"
```

Response: `{ "data": [ {entry}, ... ], "oldest": "<timestamp>" }`. Each entry:

| Field | Type | Notes |
| --- | --- | --- |
| `time` | RFC3339 string | when AdGuard received the query |
| `client` | string (IP) | source IP |
| `client_info` | object | `{name, whois, disallowed, disallowed_rule}` |
| `client_proto` | string | usually empty for plain UDP/53 |
| `question` | object | `{name, type, class}` |
| `answer` | array | `[{type, value, ttl}, ...]` (may be empty) |
| `answer_dnssec` | bool | |
| `cached` | bool | served from AdGuard's cache |
| `elapsedMs` | string (float) | processing time |
| `reason` | string | `NotFilteredNotFound`, `FilteredBlackList`, `FilteredSafeBrowsing`, `Rewrite`, etc. |
| `status` | string | DNS rcode: `NOERROR`, `NXDOMAIN`, ... |
| `rules` | array | matching filter rules: `[{filter_list_id, text}, ...]` |
| `upstream` | string | upstream that resolved the query |

Other supported query params (per OpenAPI spec): `older_than`, `response_status`
(`filtered`, `blocked`, `processed`, ...).

### GET /control/clients

Persistent + auto-detected clients.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" "$ADGUARD_URL/control/clients"
```

Shape:

```json
{
  "clients": [ {persistent client} ],
  "auto_clients": [ {ip, name, source, whois_info} ],
  "supported_tags": [ "user_admin", ... ]
}
```

A persistent client entry includes: `name`, `ids` (IP/MAC/CIDR matchers),
`tags`, `upstreams`, `filtering_enabled`, `parental_enabled`,
`safebrowsing_enabled`, `safesearch_enabled`, `use_global_settings`,
`use_global_blocked_services`, `blocked_services`, `blocked_services_schedule`,
`ignore_querylog`, `ignore_statistics`, `upstreams_cache_enabled`,
`upstreams_cache_size`.

### GET /control/clients/find

Lookup one or more clients by IP. **Param name is `ip0`, `ip1`, ... (indexed)**,
not `ip=`.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/clients/find?ip0=192.168.1.42"
```

Returns `[ { "<ip>": {client object} } ]`. The returned object is the merged
view (persistent settings if present, else auto-detected/whois data).

### GET /control/filtering/status

Filter lists + custom user rules + refresh interval.

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" "$ADGUARD_URL/control/filtering/status"
```

Top-level fields:

| Field | Type | Notes |
| --- | --- | --- |
| `enabled` | bool | global filtering toggle |
| `interval` | int (hours) | auto-update interval |
| `filters` | array | blocklists |
| `whitelist_filters` | array | allowlists |
| `user_rules` | string[] | custom rules (one per element) |

Each filter entry:

```json
{
  "id": 1,
  "name": "AdGuard DNS filter",
  "url": "https://.../filter_1.txt",
  "enabled": true,
  "rules_count": 163082,
  "last_updated": "2026-05-22T11:57:25-04:00"
}
```

`id` of a custom blocklist looks like `1753495430` (epoch when added). The
built-in lists have small IDs (`1`, `2`, ...). `last_updated` is `null` for
disabled lists that have never been pulled.

### GET /control/dns_info

Full DNS server config. Used by the wrapper's `dns-config`.

Notable fields:

| Field | Notes |
| --- | --- |
| `upstream_dns` | string[] of upstream resolvers |
| `bootstrap_dns` | string[] used to resolve upstream hostnames |
| `fallback_dns` | string[] fallback resolvers |
| `protection_enabled` | global on/off |
| `protection_disabled_until` | RFC3339 if temporarily off |
| `blocking_mode` | `default`, `nxdomain`, `null_ip`, `custom_ip` |
| `blocking_ipv4` / `blocking_ipv6` | used when blocking_mode is custom_ip |
| `blocked_response_ttl` | seconds |
| `cache_enabled`, `cache_size`, `cache_ttl_min/max`, `cache_optimistic` | |
| `dnssec_enabled`, `disable_ipv6` | |
| `ratelimit`, `ratelimit_subnet_len_ipv4/ipv6`, `ratelimit_whitelist` | |
| `resolve_clients`, `use_private_ptr_resolvers`, `local_ptr_upstreams` | |
| `upstream_mode` | `load_balance`, `parallel`, ... |
| `upstream_timeout` | seconds |
| `edns_cs_enabled`, `edns_cs_use_custom`, `edns_cs_custom_ip` | EDNS Client Subnet |

### GET /control/dhcp/status

DHCP server status. Even if DHCP isn't enabled the endpoint responds with
`{"enabled": false, ...}`.

Fields: `enabled`, `interface_name`, `v4` (dhcpv4 settings), `v6` (dhcpv6
settings), `leases`, `static_leases`.

### POST /control/protection — MUTATION

Toggle DNS filtering globally. Confirm with the user first.

```bash
curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "duration": 0}' \
  "$ADGUARD_URL/control/protection"
```

Body fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `enabled` | bool | turn protection on/off |
| `duration` | int (ms) | when disabling: auto re-enable after N ms. `0` = until manually re-enabled. |

Response: empty 200 OK. Verify via `GET /control/status` →
`protection_enabled` + `protection_disabled_duration`.

## Other commonly useful endpoints (not in the wrapper)

| Endpoint | Purpose |
| --- | --- |
| `POST /control/filtering/refresh` | manually refresh blocklists (body: `{"whitelist": false}`) |
| `POST /control/filtering/add_url` | add a blocklist |
| `POST /control/filtering/remove_url` | remove a blocklist |
| `POST /control/filtering/set_rules` | replace `user_rules` (body: `{"rules": ["..."]}`) |
| `GET /control/filtering/check_host?name=<domain>` | test what AdGuard would do with a query |
| `POST /control/stats_reset` | clear stats |
| `POST /control/querylog_clear` | clear query log |
| `GET /control/blocked_services/all` | list of known service IDs |
| `GET /control/access/list` / `POST /control/access/set` | allow/block-by-client lists |

All require the same basic auth. Consult the OpenAPI spec for full request
shapes.

## Response codes

| Code | Meaning |
| --- | --- |
| `200` | success |
| `400` | bad request body (mostly on mutations) |
| `401` | wrong basic auth credentials |
| `403` | endpoint disabled / IP-restricted |
| `404` | wrong path (likely missing `/control` prefix) |
| `500` | server-side error — check AdGuard logs |
