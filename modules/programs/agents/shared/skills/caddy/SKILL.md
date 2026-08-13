---
name: caddy
description: Inspect and manage my self-hosted Caddy reverse proxy via its admin API. Use when the user asks about Caddy, mentions reverse proxy routes, virtual hosts, TLS/cert issues for internal `.lan` domains, upstream health, or wants to view/reload the active Caddy configuration.
allowed-tools: Bash, WebFetch
---

# Caddy

Manage my self-hosted Caddy reverse proxy through its admin API: inspect the
running config, list routes and upstream pools, check the internal CA, and
hot-reload a new config file.

## Environment

The admin API URL is exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `CADDY_URL` — base URL of the admin API, no trailing slash
  (e.g. `http://192.168.1.252:2019`)

The Caddy admin API has **no authentication**. It is bound to a LAN-only
address on the LXC host; off-network access requires tailscale/VPN. The `caddy`
CLI reports a JSON error envelope when `CADDY_URL` is missing.

## CLI

Use the installed `caddy` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/caddy.sh` remains as a compatibility shim for older workflows.

```bash
caddy config                                  # GET /config/ (full active config)
caddy routes                                  # matchers + upstreams per server
caddy upstreams                               # live reverse-proxy pool + health
caddy pki-ca                                  # internal CA info (GET /pki/ca/local)
caddy reload <config.json> --confirm-reload   # POST /load, confirm first
```

For anything not covered, call the API directly with `$CADDY_URL` — see
`references/api-endpoints.md` and `references/quick-reference.md`.

## Workflow: inspect routes for a host

1. `caddy routes` to see all matchers + their upstream dials.
2. To narrow to one host:
   ```bash
   curl -fsS "$CADDY_URL/config/" | jq '
     .apps.http.servers[].routes[]
     | select(.match[]?.host[]? == "example.lan")
   '
   ```
3. To check whether an upstream is currently healthy: `caddy upstreams`.

## Workflow: TLS for internal `.lan` domains

This Caddy uses `tls.automation.issuers.module = internal`, i.e. Caddy's
built-in CA. Clients must trust Caddy's root CA cert to avoid browser
warnings:

1. `caddy pki-ca` — returns the CA's `root_certificate` (PEM).
2. Install the PEM into the client's system trust store (macOS Keychain,
   `update-ca-certificates` on Linux, mobile profile, etc.).

## Mutations: confirm first

`reload` replaces the entire active configuration atomically. Caddy validates
the new config first, but a bad config that still parses can take services
offline. **Always confirm with the user before:**

- `caddy reload <file> --confirm-reload` — replaces the running config
- Any direct `POST /load`, `PATCH /config/...`, `PUT /config/...`,
  `DELETE /config/...`, or `POST /stop` call

Require the user to say something explicit like "yes, reload" or "go ahead,
apply it" before invoking. Show them the diff of what will change first when
possible.

## References

- `references/api-endpoints.md` — admin API endpoints used here (`/config/`,
  `/load`, `/reverse_proxy/upstreams`, `/pki/ca/local`)
- `references/quick-reference.md` — copy-paste curl recipes
- `references/troubleshooting.md` — admin API reachability, invalid configs,
  internal-CA cert trust issues

## Notes

- Admin API docs: https://caddyserver.com/docs/api
- The admin API speaks JSON. Caddyfile-style configs need adapting with the
  real Caddy binary, not this garage wrapper, before posting to `/load`.
- Caddy lives on the LAN (`192.168.1.252:2019`). Off-network access requires
  tailscale or VPN.
- If `CADDY_URL` is unreachable, surface that to the user rather than
  guessing.
