---
name: tailscale
description: Inspect the local tailnet via the Tailscale CLI. Use when the user asks about tailscale, tailnet peers, exit nodes, MagicDNS, who's online over Tailscale, or wants to ping/whois a Tailscale host. Read-only — no mutations to tailnet state.
allowed-tools: Bash
---

# Tailscale

Wraps the local `tailscale` CLI on framework13. All operations are read-only:
list peers, see which exit nodes are advertised, inspect MagicDNS, look up an
IP, ping a host. No tailnet state changes.

## Environment

No secrets, no env vars. The skill uses whatever `tailscale` is on `$PATH`
(installed system-wide on framework13) and whichever tailnet the local daemon
is logged in to. `tailscale status --json` returns the full peer list, so we
do not need to call the remote Tailscale API for reads.

## Wrapper script

`scripts/tailscale.sh` exposes sub-commands. Output is JSON or formatted text.

```bash
bash scripts/tailscale.sh status              # compact peer summary (hostname/ip/online/exit)
bash scripts/tailscale.sh peers               # table: hostname, ip, OS, online
bash scripts/tailscale.sh exit-nodes          # peers advertising as exit nodes
bash scripts/tailscale.sh current-exit-node   # which exit node we're routing through
bash scripts/tailscale.sh dns                 # MagicDNS + DNS config
bash scripts/tailscale.sh ip                  # this machine's v4 and v6
bash scripts/tailscale.sh whois 100.x.y.z     # identify a tailnet IP
bash scripts/tailscale.sh ping host           # tailscale ping --c 3
bash scripts/tailscale.sh help
```

For anything not covered, fall back to `tailscale` directly. See
`references/quick-reference.md` and `references/api-endpoints.md` for the
status JSON shape.

## Topology notes

- **framework13** is this machine. The skill runs here against the local
  `tailscaled`.
- **tailscale-gateway** is a dedicated LXC (LAN 192.168.1.247, tailnet
  100.111.175.25) that advertises as exit node + subnet router for the home
  LAN. The skill sees it like any other peer; we do not SSH into it.

## Mutations

Out of scope. `up`, `down`, `logout`, `set --exit-node`, `funnel`, `serve`,
`file cp` and similar are not exposed here because they either require
interactive auth or change tailnet state. If the user wants one, surface the
command and let them run it manually.

## References

- `references/api-endpoints.md` — schema of `tailscale status --json`
- `references/quick-reference.md` — copy-paste recipes
- `references/troubleshooting.md` — daemon down, peer offline, exit node not
  advertising, MagicDNS issues
