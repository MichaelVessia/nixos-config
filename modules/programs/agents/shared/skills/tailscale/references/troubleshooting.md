# Tailscale Troubleshooting

Diagnostics for the local `tailscale` CLI on framework13. All operations
here are read-only — fixes that require mutating commands (`up`, `set ...`,
`logout`) must be run by the user, not the agent.

## Daemon / auth

### `BackendState` is not `Running`

```bash
tailscale status --json | jq '.BackendState'
```

| BackendState | Meaning                | Fix (user runs manually)                |
| ------------ | ---------------------- | --------------------------------------- |
| `Running`    | Healthy                | —                                       |
| `Starting`   | Daemon coming up       | Wait a few seconds and re-check         |
| `NeedsLogin` | Not logged in          | `tailscale up` (opens browser)          |
| `Stopped`    | `tailscale down` ran   | `tailscale up`                          |
| `NoState`    | Never authenticated    | `tailscale up`                          |

The wrapper script aborts when `BackendState != Running` so the agent will
not produce misleading output against a halted daemon.

### `AuthURL` is set

A non-empty `AuthURL` means Tailscale wants the user to re-authenticate
(node-key expiry, account change). Print the URL and tell the user to open
it; do not try to "fix" it from the agent.

```bash
tailscale status --json | jq -r '.AuthURL // "none"'
```

### `tailscale: command not found`

The CLI isn't on `$PATH`. On NixOS framework13 it should be at
`/run/current-system/sw/bin/tailscale`. Confirm:

```bash
command -v tailscale
ls /run/current-system/sw/bin/tailscale
```

If missing, the user needs to add `tailscale` to their system packages and
rebuild. Don't try to install it from the agent.

## Peer issues

### A peer shows `online: false`

That means the local daemon hasn't seen a recent keepalive from it. Common
reasons:

1. Peer is genuinely offline / asleep.
2. Peer's daemon was stopped (`tailscale down`).
3. Peer hit a key expiry — admin needs to re-auth it.
4. Coordination server lag (rare, usually < 60s).

Quick check:

```bash
tailscale status --json | jq --arg h "<hostname>" '
  ([.Self] + (.Peer | to_entries | map(.value)))
  | map(select(.HostName == $h))
  | .[0] | {hostname: .HostName, online: .Online, lastSeen: .LastSeen, lastHandshake: .LastHandshake}
'
```

Compare `LastSeen` to now. If it's recent (< 5 min), the offline flag is
probably stale; otherwise the peer really is down.

### Peer is online but `tailscale ping` only goes through DERP

This is a NAT-traversal problem, not a Tailscale-down problem. Look at:

```bash
tailscale ping --c 5 --until-direct=false <peer>
```

If every line says `via DERP(...)`, disco can't punch through. On the
gateway/peer side, check that UDP 41641 is reachable, that no host-level
firewall is blocking, and that the network isn't CGNAT-double-natted.

A pure-DERP path still works, it's just slower. Not an outage.

### Peer not found by hostname

`tailscale ping somehost` failed with "no such host":

1. MagicDNS off? `tailscale status --json | jq '.CurrentTailnet.MagicDNSEnabled'`
2. Tailscale DNS overridden by OS? `tailscale dns status` — look for
   `Tailscale DNS: enabled.` line.
3. Hostname has a different shape than expected. Find the real name:

   ```bash
   tailscale status --json | jq -r '.Peer | to_entries | .[].value | .HostName'
   ```

4. Fall back to the tailnet IP from `peers` output.

## Exit node issues

### "Exit node not advertising"

The gateway should show `ExitNodeOption: true`:

```bash
tailscale status --json | jq '
  .Peer | to_entries | .[].value
  | select(.HostName | test("gateway"; "i"))
  | {hostname: .HostName, exitNodeOption: .ExitNodeOption, online: .Online}
'
```

If `exitNodeOption` is `false`:

1. On the gateway host, `tailscale set --advertise-exit-node` must have
   been run, or `--advertise-exit-node` passed to `tailscale up`.
2. The exit node must be **approved** in the admin console (Machines →
   gateway → "Edit route settings" → enable as exit node). Without this,
   the daemon advertises it but other peers don't see the option.
3. Re-run `tailscale status --json` after approval — propagation is near
   instant.

Don't run mutating commands from the agent; tell the user what to do.

### "I set an exit node but traffic isn't routing through it"

Out of scope for this skill (mutation). But for diagnosis:

```bash
bash scripts/tailscale.sh current-exit-node
```

If `usingExitNode: false`, the OS isn't actually routed through one. The
user needs to run `sudo tailscale set --exit-node=<host>` themselves and
confirm with `--exit-node-allow-lan-access` if they need LAN reachability
while routed.

## MagicDNS issues

### `dns` subcommand prints `Access denied: watch IPN bus access denied`

Expected. `tailscale dns status` shows more info when run as root, but the
first three sections (Use Tailscale DNS, MagicDNS configuration, "Other
devices can reach this device at ...") are printed even without root and
are the only ones this skill needs. The error at the bottom is harmless
for read purposes — do not escalate to sudo.

### MagicDNS shows "disabled" but I can resolve peer names

That just means MagicDNS isn't enabled tailnet-wide in the admin console;
your machine may still resolve names through the local override. Open
`https://login.tailscale.com/admin/dns` to enable it tailnet-wide.

### `getent hosts <peer>` returns nothing

1. `tailscale dns status` — confirm `Tailscale DNS: enabled.`
2. If disabled, the system resolver isn't using Tailscale. The user can run
   `sudo tailscale set --accept-dns=true` to opt back in.
3. Some hosts strip the `.ts.net` search domain. Try the FQDN:
   `getent hosts <peer>.<suffix>.ts.net`.

## Connectivity

### `tailscale ping` says "timeout"

Either the peer is genuinely unreachable, or disco is blocked **and** DERP
is unreachable. Check:

```bash
tailscale netcheck
```

(Read-only.) Look for: a usable DERP region, UDP working, NAT type. If
DERP shows as unreachable, the network is blocking all outbound to
Tailscale's relay servers — almost always a corporate/captive firewall.

### Wrapper script exits with "tailscale CLI not found on PATH"

The shell that invoked the script doesn't have `/run/current-system/sw/bin`
on `$PATH`. Source the user's shell profile first, or invoke with an
absolute path:

```bash
PATH="/run/current-system/sw/bin:$PATH" bash scripts/tailscale.sh status
```

## Health warnings

```bash
tailscale status --json | jq '.Health'
```

Common values and what they mean:

| Health string                                          | Meaning                                  |
| ------------------------------------------------------ | ---------------------------------------- |
| `"not in map poll"`                                    | Lost control-plane connection            |
| `"state=NeedsLogin, wantRunning=true"`                 | Key expired, needs re-auth               |
| `"DERP region N: ..."`                                 | Specific relay unreachable               |
| `"router: ..."`                                        | Local routing/firewall problem           |

Empty array means everything is fine.

## When to escalate to the user

The agent shouldn't silently retry or paper over these — surface them:

- `BackendState` other than `Running`
- Non-empty `AuthURL`
- Non-empty `Health` array
- Exit node missing approval (`ExitNodeOption: false` for the gateway)
- Any mutation request (`up`, `down`, `set ...`, `logout`, `funnel`,
  `serve`, `file cp`) — print the command and let the user run it
