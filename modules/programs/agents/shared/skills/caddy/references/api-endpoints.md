# Caddy Admin API Reference

**Base URL:** `$CADDY_URL` (e.g. `http://192.168.1.252:2019`)
**Authentication:** None — admin API is bound to a LAN-only address
**Upstream docs:** https://caddyserver.com/docs/api
**Last Updated:** 2026-05-22

## Authentication

This Caddy's admin endpoint is bound to a LAN address on the LXC host with
no auth. Anyone with network reachability can hit the API, so don't expose
the admin port off-LAN.

```bash
# No auth header — just hit the URL
curl -fsS "$CADDY_URL/config/" | jq
```

## Quick Start

`CADDY_URL` comes from sops-nix and is exported into the shell by
`modules/programs/shell.nix`:

```bash
CADDY_URL=http://192.168.1.252:2019
```

Sanity check:

```bash
curl -fsS "$CADDY_URL/config/" | jq 'keys'
```

## Endpoints Used by This Skill

### Config

#### GET /config/

Return the full active configuration as JSON. Append a path to drill in,
e.g. `/config/apps/http/servers`.

**Example Request:**
```bash
curl -fsS "$CADDY_URL/config/" | jq
```

**Example Response (truncated):**
```json
{
  "admin": { "listen": ":2019" },
  "apps": {
    "http": {
      "servers": {
        "srv0": {
          "listen": [":443"],
          "routes": [
            {
              "match": [{ "host": ["sonarr.lan"] }],
              "handle": [
                {
                  "handler": "subroute",
                  "routes": [
                    {
                      "handle": [
                        {
                          "handler": "reverse_proxy",
                          "upstreams": [{ "dial": "192.168.1.38:8989" }]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    },
    "tls": {
      "automation": {
        "policies": [
          { "issuers": [{ "module": "internal" }] }
        ]
      }
    }
  }
}
```

**Response Codes:**
- `200`: Success

---

#### POST /load

Replace the entire active config atomically. Body is the new JSON config.
Caddy validates first; on failure the previous config stays active.

**This is destructive — confirm with the user before calling.**

**Example Request:**
```bash
curl -fsS -X POST -H "Content-Type: application/json" \
  --data-binary @new-config.json \
  "$CADDY_URL/load"
```

**Response Codes:**
- `200`: Config loaded
- `400`: Invalid config (body contains error message)

---

#### PATCH /config/{path} (and PUT/POST/DELETE on subpaths)

Mutate a sub-section of the running config without replacing it whole. Not
exposed via the wrapper script; use raw curl if needed and confirm first.

```bash
# Example: replace just the http app
curl -fsS -X PATCH -H "Content-Type: application/json" \
  --data-binary @http-app.json \
  "$CADDY_URL/config/apps/http"
```

Docs: https://caddyserver.com/docs/api#patch-configpath

---

### Reverse Proxy

#### GET /reverse_proxy/upstreams

Return the live upstream pool with current health info. Useful for spotting
upstreams that are marked unhealthy by Caddy's active/passive health checks.

**Example Request:**
```bash
curl -fsS "$CADDY_URL/reverse_proxy/upstreams" | jq
```

**Example Response:**
```json
[
  {
    "address": "192.168.1.38:8989",
    "num_requests": 12,
    "fails": 0
  },
  {
    "address": "192.168.1.40:7878",
    "num_requests": 3,
    "fails": 0
  }
]
```

**Response Codes:**
- `200`: Success

Docs: https://caddyserver.com/docs/api#get-reverse_proxyupstreams

---

### PKI

#### GET /pki/ca/{id}

Return information about a Caddy-managed CA. The default ID is `local`,
which is the internal CA Caddy uses when an automation policy declares
`issuers.module = internal`.

The response includes the CA's `root_certificate` (PEM) — install it into
client trust stores so `https://*.lan` works without warnings.

**Example Request:**
```bash
curl -fsS "$CADDY_URL/pki/ca/local" | jq
```

**Example Response:**
```json
{
  "id": "local",
  "name": "Caddy Local Authority",
  "root_common_name": "Caddy Local Authority - 2026 ECC Root",
  "intermediate_common_name": "Caddy Local Authority - ECC Intermediate",
  "root_certificate": "-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----\n",
  "intermediate_certificate": "-----BEGIN CERTIFICATE-----\nMIIB...\n-----END CERTIFICATE-----\n"
}
```

**Response Codes:**
- `200`: Success
- `404`: No such CA

Docs: https://caddyserver.com/docs/api#get-pkicaid

---

### Lifecycle

#### POST /stop

Gracefully shut down the running Caddy process. Almost never what you want
on this host — Caddy is supervised by systemd in the LXC and will be
restarted. Not exposed via the wrapper.

```bash
curl -fsS -X POST "$CADDY_URL/stop"
```

---

## Path Conventions

- All admin API paths are absolute under the admin endpoint root.
- Trailing slash on `/config/` matters (returns the whole tree).
- Sub-paths like `/config/apps/http/servers/srv0/routes` work for both GETs
  and mutations.

## Version History

| API Version | Doc Version | Date       | Changes               |
|-------------|-------------|------------|-----------------------|
| v2 admin    | 1.0.0       | 2026-05-22 | Initial documentation |

## Additional Resources

- [Caddy Admin API](https://caddyserver.com/docs/api)
- [JSON Config Structure](https://caddyserver.com/docs/json/)
- [Reverse Proxy Module](https://caddyserver.com/docs/modules/http.handlers.reverse_proxy)
- [Internal CA / PKI](https://caddyserver.com/docs/automatic-https#local-https)
