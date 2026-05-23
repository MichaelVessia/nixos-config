# Tailscale Skill

Read-only wrapper around the local `tailscale` CLI: inspect peers, exit
nodes, MagicDNS, and connectivity from any agent (Claude, Codex, opencode).

## What's here

```
tailscale/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── tailscale.sh    # Wrapper exposing sub-commands (status, peers, …)
└── references/
    ├── api-endpoints.md     # `tailscale status --json` schema
    ├── quick-reference.md   # Copy-paste recipes
    └── troubleshooting.md   # Daemon/peer/exit-node/DNS issues
```

## Setup

Nothing to configure. This skill talks to the local `tailscale` CLI, which is
already installed system-wide on framework13 and authenticated to the user's
tailnet. There is no sops secret and no `TAILSCALE_API_KEY` env var — the
local daemon already knows the full peer list and exposes it through
`tailscale status --json`.

Sanity check:

```bash
bash scripts/tailscale.sh status
```

If `tailscale` is missing or the daemon is not logged in, the script aborts
with a clear message.

## Sub-commands

All commands are run as `bash scripts/tailscale.sh <cmd> [args]`.

| Command                  | What it does                                      |
| ------------------------ | ------------------------------------------------- |
| `status`                 | Compact JSON per peer (hostname/ip/online/exit)   |
| `peers`                  | Aligned table of all peers                        |
| `exit-nodes`             | Peers offering exit-node service                  |
| `current-exit-node`      | Which peer we're routing through, if any          |
| `dns`                    | `tailscale dns status` (MagicDNS state)           |
| `ip`                     | This machine's IPv4 + IPv6 tailnet addresses      |
| `whois <ip-or-host>`     | Identify a tailnet IP (`tailscale whois`)         |
| `ping <host>`            | `tailscale ping --c 3 <host>`                     |
| `help`                   | Usage                                             |

## Tailnet topology

- **framework13** runs the agents and this skill.
- **tailscale-gateway** is a dedicated LXC on the LAN:
  - LAN IP: `192.168.1.247`
  - Tailnet IP: `100.111.175.25`
  - Role: exit node + subnet router for `192.168.1.0/24`
  - It shows up in `peers` and `exit-nodes` output like any other host.

The skill does not SSH into the gateway; `tailscale status --json` returns
the full tailnet view from the local daemon.

## Notes

- Requires `tailscale` and `jq`. Both are present in the system shell.
- Read-only by design. Mutations (`up`, `set --exit-node`, `funnel`, `serve`,
  `logout`, etc.) are intentionally not exposed because they need
  interactive auth or change tailnet state.
- If you need to mutate, surface the command to the user and let them run it.
