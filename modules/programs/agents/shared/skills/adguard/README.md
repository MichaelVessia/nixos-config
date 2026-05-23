# AdGuard Home Skill

Wrapper for the self-hosted AdGuard Home HTTP API: inspect status, query logs,
stats, filters, and DNS clients from any agent (Claude, Codex, opencode).

## What's here

```
adguard/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── adguard.sh      # Wrapper exposing sub-commands (status, stats, query-log, …)
└── references/
    ├── api-endpoints.md      # /control/* endpoint reference
    ├── quick-reference.md    # Copy-paste curl recipes
    └── troubleshooting.md    # Auth/connection/DNS-side fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.adguard_url.owner = "michaelvessia";
   secrets.adguard_username.owner = "michaelvessia";
   secrets.adguard_password.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   adguard_url: http://192.168.1.109
   adguard_username: <admin user>
   adguard_password: <plaintext password — bcrypt-hashed inside AdGuardHome.yaml>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/adguard_url" ]      && export ADGUARD_URL="$(cat "$SECRETS_DIR/adguard_url")"
   [ -f "$SECRETS_DIR/adguard_username" ] && export ADGUARD_USERNAME="$(cat "$SECRETS_DIR/adguard_username")"
   [ -f "$SECRETS_DIR/adguard_password" ] && export ADGUARD_PASSWORD="$(cat "$SECRETS_DIR/adguard_password")"
   ```

## Sub-commands

All commands are run as `bash scripts/adguard.sh <cmd> [args]`.

| Command                          | What it does                                            |
| -------------------------------- | ------------------------------------------------------- |
| `status`                         | `GET /control/status` — version, running, protection    |
| `version`                        | Just the version string                                 |
| `stats`                          | 24h counters + top queried/blocked/clients              |
| `stats-info`                     | Stats retention interval (days)                         |
| `query-log [n]`                  | Last n querylog entries (default 50)                    |
| `query-log-search <substring>`   | Server-side substring search of querylog                |
| `clients`                        | Configured clients + auto-detected sample               |
| `clients-active <ip>`            | Lookup one client by IP                                 |
| `filters`                        | Blocklists, allowlists, custom rule count               |
| `rules`                          | Just the custom `user_rules`                            |
| `dns-config`                     | Full DNS server config (`/dns_info`)                    |
| `dhcp-status`                    | DHCP server status (if enabled)                         |
| `protection-toggle <on\|off>`    | MUTATION — globally toggle DNS filtering. Confirm first |

## Workflows

**Investigate a domain that got blocked**

```bash
bash scripts/adguard.sh query-log-search example.com
bash scripts/adguard.sh filters
bash scripts/adguard.sh rules
```

**Find the noisiest client**

```bash
bash scripts/adguard.sh stats | jq '.top_clients'
bash scripts/adguard.sh clients-active 192.168.1.42
```

## Notes

- Requires `curl` and `jq` (both already in the dev shell).
- API base is `/control/` — no `/api/v1/` prefix exists.
- Live instance: `http://192.168.1.109` (LXC 106), AdGuard Home v0.107.67.
- HTTP basic auth only. Password is bcrypt-hashed in `AdGuardHome.yaml` on
  the server; rotation means editing that file directly. See
  `references/troubleshooting.md`.
