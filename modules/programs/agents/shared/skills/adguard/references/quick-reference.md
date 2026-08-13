# AdGuard Home Quick Reference

Copy-paste curl recipes for common operations.

## Setup

`ADGUARD_URL`, `ADGUARD_USERNAME`, `ADGUARD_PASSWORD` are exported into the
shell by sops-nix via `modules/programs/shell.nix`. No `source` step — just
use the variables directly:

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/status" | jq
```

Auth header for every call: `-u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD"`. The
base path is `/control/` — there is no `/api/v1/` prefix.

## System

### Status / version

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/status" | \
  jq '{version, running, protection_enabled, dns_addresses}'
```

### Stats (24h)

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/stats" | \
  jq '{
    num_dns_queries,
    num_blocked_filtering,
    top_queried: (.top_queried_domains[:5]),
    top_blocked: (.top_blocked_domains[:5]),
    top_clients: (.top_clients[:5])
  }'
```

### Stats retention

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/stats_info"
```

## Query log

### Recent queries

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/querylog?limit=50" | \
  jq '.data[] | {time, client, q: .question.name, status, reason}'
```

### Search the log (server-side substring)

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/querylog?search=netflix&limit=200" | \
  jq '.data[] | {time, client, q: .question.name, reason, rules: .rules}'
```

### Only show blocked queries

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/querylog?response_status=blocked&limit=100" | \
  jq '.data[] | {time, client, q: .question.name, rule: (.rules[0].text // null)}'
```

## Filters and rules

### List blocklists

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/filtering/status" | \
  jq '.filters[] | {id, name, enabled, rules_count, last_updated}'
```

### Just the custom user rules

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/filtering/status" | \
  jq '.user_rules'
```

### What would AdGuard do with this domain?

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/filtering/check_host?name=doubleclick.net" | jq
```

### Refresh blocklists (MUTATION — confirm first)

```bash
curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"whitelist": false}' \
  "$ADGUARD_URL/control/filtering/refresh"
```

## Clients

### Configured + auto-detected

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/clients" | \
  jq '{
    configured: [.clients[] | {name, ids, upstreams}],
    auto_count: (.auto_clients | length)
  }'
```

### Lookup one IP (note: param is `ip0`, not `ip`)

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/clients/find?ip0=192.168.1.42" | jq
```

### Lookup multiple IPs in one call

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/clients/find?ip0=192.168.1.42&ip1=192.168.1.43" | jq
```

## DNS config

### Full DNS info

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/dns_info" | jq
```

### Just upstreams

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/dns_info" | \
  jq '{upstream_dns, bootstrap_dns, fallback_dns, upstream_mode, upstream_timeout}'
```

## DHCP

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/dhcp/status" | \
  jq '{enabled, interface_name, leases: (.leases | length), static_leases: (.static_leases | length)}'
```

## Protection toggle — MUTATION

Confirm with the user before running. The whole LAN loses ad/tracker blocking
while protection is off.

### Disable indefinitely

```bash
curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "duration": 0}' \
  "$ADGUARD_URL/control/protection"
```

### Disable for 5 minutes (auto re-enable)

```bash
curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "duration": 300000}' \
  "$ADGUARD_URL/control/protection"
```

`duration` is in **milliseconds**, not seconds. `0` means "until manually
re-enabled".

### Re-enable

```bash
curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "duration": 0}' \
  "$ADGUARD_URL/control/protection"
```

### Verify

```bash
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/status" | \
  jq '{protection_enabled, protection_disabled_duration}'
```

## Workflows

### Workflow: investigate why a domain is being blocked

```bash
# 1. Ask AdGuard directly what it would do with the domain
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/filtering/check_host?name=ads.example.com" | jq

# 2. See recent hits in the query log
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/querylog?search=ads.example.com&limit=50" | \
  jq '.data[] | {time, client, reason, rules}'

# 3. Identify the filter list ID flagging it
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/filtering/status" | \
  jq '.filters[] | {id, name}'
```

### Workflow: find the noisiest client

```bash
top_ip=$(curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/stats" | jq -r '.top_clients[0] | keys[0]')
echo "noisiest: $top_ip"
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/clients/find?ip0=$top_ip" | jq
```

### Workflow: pause AdGuard temporarily for a misbehaving app

```bash
# Disable for 60s, then verify it's back
curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false, "duration": 60000}' \
  "$ADGUARD_URL/control/protection"

sleep 65
curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
  "$ADGUARD_URL/control/status" | jq '.protection_enabled'
```
