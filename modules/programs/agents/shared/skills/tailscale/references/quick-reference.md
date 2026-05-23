# Tailscale Quick Reference

Common read-only operations against the local `tailscale` CLI.

## Setup

Nothing. The local `tailscaled` is already authenticated on framework13.

Sanity check:

```bash
tailscale status --json | jq '.BackendState'   # expect: "Running"
```

## Status & peers

### Compact per-peer summary

```bash
bash scripts/tailscale.sh status
```

### Aligned table of all peers

```bash
bash scripts/tailscale.sh peers
```

### Just this machine

```bash
tailscale status --json | jq '{
  hostname: .Self.HostName,
  dnsName: .Self.DNSName,
  ipv4: (.Self.TailscaleIPs[0] // null),
  ipv6: (.Self.TailscaleIPs[1] // null),
  online: .Self.Online,
  magicDNSSuffix: .MagicDNSSuffix
}'
```

### This machine's tailnet IPs

```bash
bash scripts/tailscale.sh ip
# or directly:
tailscale ip -4
tailscale ip -6
```

## Exit nodes

### Who is offering exit-node service?

```bash
bash scripts/tailscale.sh exit-nodes
```

### Am I routing through an exit node?

```bash
bash scripts/tailscale.sh current-exit-node
```

### Online exit nodes only (raw jq)

```bash
tailscale status --json | jq '[
  .Peer | to_entries | .[].value
  | select(.ExitNodeOption == true and .Online == true)
  | {hostname: .HostName, ip: (.TailscaleIPs[0])}
]'
```

### Find the homelab gateway

```bash
tailscale status --json | jq '
  .Peer | to_entries | .[].value
  | select(.HostName | test("gateway"; "i"))
  | {hostname: .HostName, ip: (.TailscaleIPs[0]), online: .Online, exitNodeOption: .ExitNodeOption}
'
```

## DNS / MagicDNS

### Show DNS state

```bash
bash scripts/tailscale.sh dns
```

Look for:
- `Tailscale DNS: enabled.` — local resolver is overridden
- `MagicDNS: enabled tailnet-wide (suffix = <name>.ts.net)` — tailnet-wide on
- the line `Other devices in your tailnet can reach this device at <fqdn>`

The `Failed to fetch network map: Access denied` lines at the bottom are
expected when not running as root and can be ignored for read use.

### Resolve a MagicDNS name

```bash
# Use the OS resolver — Tailscale DNS will answer if MagicDNS is on
getent hosts framework13   # or any peer hostname
```

## Identifying an IP

### Whois (CLI)

```bash
bash scripts/tailscale.sh whois 100.111.175.25
```

### Hostname from IP via status JSON

```bash
tailscale status --json | jq -r --arg ip "100.111.175.25" '
  ([.Self] + (.Peer | to_entries | map(.value)))
  | map(select(.TailscaleIPs | index($ip)))
  | .[0].HostName // "unknown"
'
```

## Connectivity

### Ping a peer (3 packets)

```bash
bash scripts/tailscale.sh ping framework13
```

Output tells you `via DERP(...)` (relayed) vs `direct ...` (NAT punched
through). First ping is often relayed; subsequent ones go direct once disco
works.

### Continuous ping with explicit count

```bash
tailscale ping --c 10 framework13
```

### Test through-WireGuard ICMP

```bash
tailscale ping --c 3 --icmp framework13
```

## Subnet routes

### What routes does a peer advertise?

```bash
tailscale status --json | jq -r --arg host "tailscale-gateway" '
  .Peer | to_entries | .[].value
  | select(.HostName == $host)
  | .AllowedIPs[]?
'
```

## Health

### Any warnings?

```bash
tailscale status --json | jq '.Health'
# empty array == healthy
```

### Client update available?

```bash
tailscale status --json | jq '.ClientVersion'
```

## Tailnet topology cheat sheet

| Host                 | LAN IP          | Tailnet IP        | Role                          |
| -------------------- | --------------- | ----------------- | ----------------------------- |
| framework13          | (this machine)  | (run `ip` cmd)    | Agent host, this skill runs here |
| tailscale-gateway    | 192.168.1.247   | 100.111.175.25    | Exit node + subnet router     |

To re-discover the gateway dynamically:

```bash
tailscale status --json | jq '
  .Peer | to_entries | .[].value
  | select(.HostName | test("gateway"; "i"))
  | {hostname: .HostName, tailnetIP: (.TailscaleIPs[0]),
     online: .Online, exitNodeOption: .ExitNodeOption,
     routes: .AllowedIPs}
'
```

## What this skill won't do

Mutations need interactive auth or change tailnet state. Surface the command
to the user rather than running it from the agent:

| Want to...                | Run manually                              |
| ------------------------- | ----------------------------------------- |
| Log in                    | `tailscale up`                            |
| Use an exit node          | `sudo tailscale set --exit-node=<host>`   |
| Stop using an exit node   | `sudo tailscale set --exit-node=`         |
| Advertise this host as one| `sudo tailscale set --advertise-exit-node`|
| Share a file              | `tailscale file cp <file> <host>:`        |
| Expose a service          | `tailscale serve <port>` / `funnel <port>`|
