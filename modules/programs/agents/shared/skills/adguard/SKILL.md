---
name: adguard
description: Inspect and manage my self-hosted AdGuard Home DNS sinkhole. Use when the user asks about AdGuard, DNS blocking, query logs, blocklists/filters, top queried or blocked domains, DNS clients, or wants to toggle protection.
allowed-tools: Bash, WebFetch
---

# AdGuard Home

Manage my self-hosted AdGuard Home (DNS sinkhole / ad-blocker) instance. Inspect
status, query logs, stats, configured clients, and filter lists. Toggle DNS
protection (mutation — confirm first).

## Environment

Credentials come from sops-nix (see `modules/programs/shell.nix`):

- `ADGUARD_URL` — base URL (no trailing slash), e.g. `http://192.168.1.109`
- `ADGUARD_USERNAME` — HTTP basic auth user
- `ADGUARD_PASSWORD` — HTTP basic auth password

The `adguard` CLI reports a JSON error envelope when they are missing. All API
calls hit the `/control/` base path and pass HTTP basic auth.

## CLI

Use the installed `adguard` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/adguard.sh` remains as a compatibility shim for older workflows.

```bash
adguard status                                      # version, running, protection, dns addrs
adguard version                                     # just version string
adguard stats                                       # 24h query/block counts + top domains
adguard stats-info                                  # stats retention interval (days)
adguard query-log --limit 50                        # recent querylog entries
adguard query-log-search example.com --limit 200    # search recent querylog
adguard clients                                     # configured and auto-detected clients
adguard clients-active <ip>                         # lookup one client by IP
adguard filters                                     # blocklists, allowlists, custom rule count
adguard rules                                       # custom user_rules only
adguard dns-config                                  # full DNS server config
adguard dhcp-status                                 # DHCP server status (if enabled)
adguard protection-toggle on --confirm-toggle       # MUTATION, confirm first
```

For anything not covered, call the API directly with `$ADGUARD_URL` plus
`-u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD"` — see `references/api-endpoints.md`
and `references/quick-reference.md`.

## Workflow: investigating a blocked domain

1. `adguard query-log-search example.com` — see when/who hit it.
2. `adguard filters` — see which list flagged it (the `rules`
   field in querylog points to filter ID + line).
3. `adguard rules` — check custom user rules for overrides.

## Workflow: who is querying

1. `adguard stats` — top clients by query count.
2. `adguard clients-active <ip>` — resolve an IP to its
   configured client profile and per-client overrides.

## Mutations: confirm first

Always confirm with the user before:

- `adguard protection-toggle on|off --confirm-toggle` (disables DNS filtering globally — every device
  on the LAN loses ad/tracker blocking until re-enabled)
- Any custom POST/PUT against `/control/*` (filter add/remove, DNS config
  changes, DHCP changes, client edits)

## References

- `references/api-endpoints.md` — endpoints used by the CLI, with response
  shapes verified against the live instance (v0.107.67)
- `references/quick-reference.md` — copy-paste curl recipes
- `references/troubleshooting.md` — 401/403, connection, DNS-side issues

## Notes

- API base path is `/control/` (not `/api/v1/`).
- HTTP basic auth only. The password is stored bcrypt-hashed in
  `AdGuardHome.yaml`; rotating it means editing that YAML, not a UI setting.
- Live instance: `http://192.168.1.109` (LXC 106), v0.107.67.
- Wiki: https://github.com/AdguardTeam/AdGuardHome/wiki/API
- OpenAPI spec: https://github.com/AdguardTeam/AdGuardHome/blob/master/openapi/openapi.yaml
