# Caddy Skill

Wrapper for the self-hosted Caddy admin API: inspect routes, check upstream
health, view the internal CA, and reload configs from any agent (Claude,
Codex, opencode).

## What's here

```
caddy/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── caddy.sh        # Wrapper exposing sub-commands (config, routes, …)
└── references/
    ├── api-endpoints.md      # Admin API endpoint reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Reachability / config / cert fixes
```

## Setup

The Caddy admin URL comes from sops-nix, not a `.env` file.

1. Declared as a secret in `modules/secrets/default.nix`:
   ```nix
   secrets.caddy_url.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   caddy_url: http://192.168.1.252:2019
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/caddy_url" ] && export CADDY_URL="$(cat "$SECRETS_DIR/caddy_url")"
   ```

The admin API has **no authentication**. It is bound to a LAN-only address
on the LXC host. Off-network access requires tailscale or VPN.

## Sub-commands

All commands are run as `bash scripts/caddy.sh <cmd> [args]`.

| Command                  | What it does                                            |
| ------------------------ | ------------------------------------------------------- |
| `config`                 | `GET /config/` — full active config (jq pretty-printed) |
| `routes`                 | Per-server matchers + reverse-proxy upstreams           |
| `upstreams`              | `GET /reverse_proxy/upstreams` — live pool + health     |
| `pki-ca`                 | `GET /pki/ca/local` — info about Caddy's internal CA    |
| `reload <config.json>`   | `POST /load` — replace active config (destructive)      |
| `help`                   | Usage                                                   |

## Workflows

**Inspect a single host's route**

```bash
bash scripts/caddy.sh routes
# narrow further:
curl -fsS "$CADDY_URL/config/" | jq '
  .apps.http.servers[].routes[]
  | select(.match[]?.host[]? == "example.lan")
'
```

**Trust the internal CA on a new client** — see
`references/quick-reference.md` and `references/troubleshooting.md` for
exporting and trusting Caddy's root certificate.

**Reload a new config** — see
`references/quick-reference.md#reload-config-from-file`. Confirm with the
user first; `POST /load` swaps the entire active config.

## Notes

- Requires `curl` and `jq` (both already in the dev shell).
- Caddy lives on the LAN (`192.168.1.252:2019`). Off-network access requires
  tailscale or VPN.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command can be done with raw curl against `$CADDY_URL` using the
  examples in `references/`.
- Upstream docs: https://caddyserver.com/docs/api
