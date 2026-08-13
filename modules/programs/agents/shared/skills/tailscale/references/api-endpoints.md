# Tailscale Local CLI JSON Reference

**CLI:** `tailscale` (local binary)
**Source of truth:** the local `tailscaled` socket
**Authentication:** none — runs as the logged-in user on framework13
**Last Updated:** 2026-05-22

This skill does **not** call the remote Tailscale API (`api.tailscale.com`).
All data comes from the local CLI, which talks to the local daemon. The
JSON shape below is stable enough to treat as an API contract.

## Daemon health check

```bash
tailscale status --json | jq '.BackendState'
```

| BackendState | Meaning                                              |
| ------------ | ---------------------------------------------------- |
| `Running`    | Daemon up, logged in, healthy                        |
| `Starting`   | Daemon coming up                                     |
| `NeedsLogin` | Daemon up, no auth — run `tailscale up` (interactive)|
| `Stopped`    | `tailscale down` was called                          |
| `NoState`    | Daemon never set up                                  |

## `tailscale status --json`

Top-level keys (Tailscale 1.90.x):

| Key              | Type   | Purpose                                                 |
| ---------------- | ------ | ------------------------------------------------------- |
| `Version`        | string | Client version                                          |
| `BackendState`   | string | See table above                                         |
| `AuthURL`        | string | Non-empty when re-auth is required                      |
| `TailscaleIPs`   | array  | This node's tailnet IPs (v4 then v6)                    |
| `Self`           | object | This node — same shape as a Peer entry                  |
| `Peer`           | object | Map of `<pubkey>` -> peer object                        |
| `User`           | object | Map of user IDs to user records                         |
| `CurrentTailnet` | object | `Name`, `MagicDNSSuffix`, `MagicDNSEnabled`             |
| `MagicDNSSuffix` | string | e.g. `bison-gray.ts.net`                                |
| `Health`         | array  | Health warnings, empty when healthy                     |
| `ClientVersion`  | object | Update info                                             |
| `CertDomains`    | array  | Domains for which the node can mint HTTPS certs         |
| `TUN`            | bool   | True if using the TUN interface                         |
| `HaveNodeKey`    | bool   | True if the node has a key (i.e. logged in once)        |

### Peer object

Returned both for `Self` and for every entry in `Peer`. Most useful fields:

| Field             | Type    | Purpose                                                 |
| ----------------- | ------- | ------------------------------------------------------- |
| `ID`              | string  | Stable node ID                                          |
| `PublicKey`       | string  | WireGuard public key                                    |
| `HostName`        | string  | Short hostname                                          |
| `DNSName`         | string  | Full MagicDNS name, e.g. `foo.bison-gray.ts.net.`       |
| `OS`              | string  | `linux`, `macOS`, `iOS`, `android`, `windows`           |
| `UserID`          | int     | Owning user                                             |
| `TailscaleIPs`    | array   | Tailnet IPs (v4 then v6)                                |
| `Addrs`           | array   | Raw endpoints                                           |
| `CurAddr`         | string  | Current direct endpoint (empty when relayed)            |
| `Relay`           | string  | DERP relay name when not direct                         |
| `Online`          | bool    | Currently connected                                     |
| `ExitNode`        | bool    | This peer IS the exit node we're using                  |
| `ExitNodeOption`  | bool    | This peer offers itself as an exit node                 |
| `Active`          | bool    | Recently exchanged traffic                              |
| `LastSeen`        | string  | RFC3339 timestamp                                       |
| `LastHandshake`   | string  | RFC3339 timestamp                                       |
| `RxBytes`         | int     | Bytes received from this peer                           |
| `TxBytes`         | int     | Bytes sent to this peer                                 |
| `Tags`            | array   | ACL tags (`tag:server`, `tag:exit`, ...)                |
| `AllowedIPs`      | array   | Routes advertised by this peer (subnet router)          |
| `TaildropTarget`  | int     | Taildrop reachability                                   |

### Example: list peers

```bash
tailscale status --json | jq '.Peer | to_entries | map({
  hostname: .value.HostName,
  ip: (.value.TailscaleIPs[0] // null),
  online: .value.Online,
  exitNode: .value.ExitNode,
  exitNodeOption: .value.ExitNodeOption
})'
```

### Example: find exit nodes

```bash
tailscale status --json | jq '[
  .Peer | to_entries | .[].value
  | select(.ExitNodeOption == true)
  | {hostname: .HostName, ip: (.TailscaleIPs[0] // null), online: .Online, current: .ExitNode}
]'
```

### Example: which exit node am I using

```bash
tailscale status --json | jq '
  (.Peer // {} | to_entries | map(.value) | map(select(.ExitNode == true)) | .[0])
  | if . == null then "none" else {hostname: .HostName, ip: (.TailscaleIPs[0])} end
'
```

## `tailscale dns status`

Plain text, not JSON. Three sections:

1. **Use Tailscale DNS** — whether the OS resolver is being overridden.
2. **MagicDNS configuration** — server-side state (enabled tailnet-wide,
   suffix, this node's reachable name).
3. **Resolver / routes** — only when run as root. Without root you'll see
   `Access denied: watch IPN bus access denied`; that is expected and
   non-fatal for read use.

```bash
tailscale dns status
```

## `tailscale ip`

```bash
tailscale ip -4   # IPv4 tailnet address, e.g. 100.x.y.z
tailscale ip -6   # IPv6 tailnet address, e.g. fd7a:...
```

Outputs one address per line. No JSON option needed.

## `tailscale whois`

```bash
tailscale whois 100.x.y.z          # human-readable
tailscale whois --json 100.x.y.z   # JSON
```

JSON shape (subset):

```json
{
  "Node": {
    "ID": "n123CNTRL",
    "Name": "framework13.bison-gray.ts.net.",
    "User": 42,
    "Addresses": ["100.x.y.z/32", "fd7a:.../128"],
    "Hostinfo": { "OS": "linux", "Hostname": "framework13" }
  },
  "UserProfile": {
    "ID": 42,
    "LoginName": "user@example.com",
    "DisplayName": "User Name"
  }
}
```

## `tailscale ping`

```bash
tailscale ping --c 3 framework13       # by hostname (MagicDNS)
tailscale ping --c 3 100.111.175.25    # by tailnet IP
```

Output is plain text. Each line tells you whether the round-trip went
direct (`direct ...`) or through DERP (`via DERP(nyc)`). Useful for
diagnosing NAT/firewall issues.

Flags worth knowing:

| Flag             | Effect                                                |
| ---------------- | ----------------------------------------------------- |
| `--c <n>`        | Max number of pings (note: single-dash style flag)    |
| `--until-direct` | Stop once a direct path is established (default on)   |
| `--icmp`         | ICMP-level ping over WireGuard                        |
| `--tsmp`         | TSMP-level ping (bypasses both host stacks)           |
| `--timeout <d>`  | Per-ping timeout (default 5s)                         |

## Things this skill intentionally does not do

The local CLI exposes many state-changing operations. None are wrapped here
because they need interactive auth or modify tailnet state:

- `tailscale up` / `down` / `logout`
- `tailscale set --exit-node=...` / `--advertise-exit-node` / `--ssh`
- `tailscale serve` / `tailscale funnel`
- `tailscale file cp` / `file get` (Taildrop)
- `tailscale cert`

If the user wants one, surface the command and let them run it manually.

## Remote API (not used here)

If you ever need tailnet-wide admin actions (create auth keys, delete
devices, edit ACLs) those live at `https://api.tailscale.com/api/v2/...` and
require a separate `TAILSCALE_API_KEY`. That is out of scope for this skill;
add a new skill if and when it's needed.
