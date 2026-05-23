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

The wrapper asserts these are set and aborts cleanly otherwise. All API calls
hit the `/control/` base path and pass `-u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD"`.

## Wrapper script

`scripts/adguard.sh` exposes sub-commands so the agent doesn't have to hand-roll
curl. Output is JSON or pre-formatted text.

```bash
bash scripts/adguard.sh status                      # version, running, protection, dns addrs
bash scripts/adguard.sh stats                       # 24h query/block counts + top domains
bash scripts/adguard.sh stats-info                  # stats retention interval (days)
bash scripts/adguard.sh query-log [n]               # last n querylog entries (default 50)
bash scripts/adguard.sh query-log-search <substr>   # search querylog (limit 200)
bash scripts/adguard.sh clients                     # configured persistent clients
bash scripts/adguard.sh clients-active <ip>         # lookup one client by IP
bash scripts/adguard.sh filters                     # blocklists, allowlists, custom rule count
bash scripts/adguard.sh rules                       # custom user_rules only
bash scripts/adguard.sh dns-config                  # full DNS server config
bash scripts/adguard.sh dhcp-status                 # DHCP server status (if enabled)
bash scripts/adguard.sh version                     # just version string
bash scripts/adguard.sh protection-toggle on|off    # MUTATION — confirm first
```

For anything not covered, call the API directly with `$ADGUARD_URL` plus
`-u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD"` — see `references/api-endpoints.md`
and `references/quick-reference.md`.

## Workflow: investigating a blocked domain

1. `bash scripts/adguard.sh query-log-search example.com` — see when/who hit it.
2. `bash scripts/adguard.sh filters` — see which list flagged it (the `rules`
   field in querylog points to filter ID + line).
3. `bash scripts/adguard.sh rules` — check custom user rules for overrides.

## Workflow: who is querying

1. `bash scripts/adguard.sh stats` — top clients by query count.
2. `bash scripts/adguard.sh clients-active <ip>` — resolve an IP to its
   configured client profile and per-client overrides.

## Mutations: confirm first

Always confirm with the user before:

- `protection-toggle on|off` (disables DNS filtering globally — every device
  on the LAN loses ad/tracker blocking until re-enabled)
- Any custom POST/PUT against `/control/*` (filter add/remove, DNS config
  changes, DHCP changes, client edits)

## References

- `references/api-endpoints.md` — endpoints used by the wrapper, with response
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
