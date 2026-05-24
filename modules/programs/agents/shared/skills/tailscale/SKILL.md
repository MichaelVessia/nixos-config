---
name: tailscale
description: Inspect the local tailnet via the Tailscale CLI. Use when the user asks about tailscale, tailnet peers, exit nodes, MagicDNS, who's online over Tailscale, or wants to ping/whois a Tailscale host. Read-only — no mutations to tailnet state.
allowed-tools: Bash
---

# Tailscale

Wraps the local Tailscale daemon on framework13. All operations are read-only:
list peers, see which exit nodes are advertised, inspect MagicDNS, look up an
IP, ping a host. No tailnet state changes.

## Environment

No secrets, no env vars. The installed `tailscale` CLI is a garage wrapper that
uses the system Tailscale binary (`/run/current-system/sw/bin/tailscale`) and
whichever tailnet the local daemon is logged in to. `tailscale status --json`
from the system binary returns the full peer list, so we do not need to call the
remote Tailscale API for reads.

## CLI

Use the installed `tailscale` CLI for common operations. It always emits a
single JSON envelope with `ok`, `command`, `result` or `error`, and
`next_actions`. `scripts/tailscale.sh` remains as a compatibility shim for
older workflows.

```bash
tailscale status --limit 25                   # compact peer summary (hostname/ip/online/exit)
tailscale peers --limit 50                    # peers with hostname, IP, OS, online
tailscale exit-nodes --limit 25               # peers advertising as exit nodes
tailscale current-exit-node                   # which exit node we're routing through
tailscale dns                                 # MagicDNS + DNS config
tailscale ip                                  # this machine's v4 and v6
tailscale whois 100.x.y.z                     # identify a tailnet IP
tailscale ping host                           # system tailscale ping --c 3
```

For raw Tailscale commands not covered by the garage wrapper, call
`/run/current-system/sw/bin/tailscale` explicitly. See
`references/quick-reference.md` and `references/api-endpoints.md` for the status
JSON shape.

## Topology notes

- **framework13** is this machine. The skill runs here against the local
  `tailscaled`.
- **tailscale-gateway** is a dedicated LXC (LAN 192.168.1.247, tailnet
  100.111.175.25) that advertises as exit node + subnet router for the home
  LAN. The skill sees it like any other peer; we do not SSH into it.

## Mutations

Out of scope. `up`, `down`, `logout`, `set --exit-node`, `funnel`, `serve`,
`file cp` and similar are not exposed here because they either require
interactive auth or change tailnet state. If the user wants one, surface the raw
`/run/current-system/sw/bin/tailscale ...` command and let them run it manually.

## References

- `references/api-endpoints.md` — schema of `tailscale status --json`
- `references/quick-reference.md` — copy-paste recipes
- `references/troubleshooting.md` — daemon down, peer offline, exit node not
  advertising, MagicDNS issues
