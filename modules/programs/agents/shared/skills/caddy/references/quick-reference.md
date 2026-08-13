# Caddy Quick Reference

Common operations for quick copy-paste usage against the admin API.

## Setup

`CADDY_URL` is exported into the shell by sops-nix via
`modules/programs/shell.nix`. No `source` step required — just use the
variable directly:

```bash
curl -fsS "$CADDY_URL/config/" | jq 'keys'
```

The admin API has no auth on this host; do not expose the admin port off-LAN.

## Config Inspection

### Full active config

```bash
curl -fsS "$CADDY_URL/config/" | jq
```

### Just the http servers

```bash
curl -fsS "$CADDY_URL/config/apps/http/servers" | jq
```

### Narrow to a single host

```bash
HOST=sonarr.lan
curl -fsS "$CADDY_URL/config/" | jq --arg h "$HOST" '
  .apps.http.servers[].routes[]
  | select(.match[]?.host[]? == $h)
'
```

### List every host -> upstream mapping

```bash
curl -fsS "$CADDY_URL/config/" | jq -r '
  .apps.http.servers[].routes[] as $r
  | ($r.match[]?.host[]?) as $host
  | ($r | .. | objects | select(.handler? == "reverse_proxy") | .upstreams[]?.dial) as $up
  | "\($host) -> \($up)"
'
```

### Dump TLS automation policies

```bash
curl -fsS "$CADDY_URL/config/apps/tls/automation" | jq
```

## Reverse Proxy Upstreams

### Live upstream health

```bash
curl -fsS "$CADDY_URL/reverse_proxy/upstreams" | jq
```

### Only unhealthy upstreams

```bash
curl -fsS "$CADDY_URL/reverse_proxy/upstreams" \
  | jq '.[] | select(.fails > 0 or .healthy == false)'
```

## Internal CA (PKI)

### Inspect the local CA

```bash
curl -fsS "$CADDY_URL/pki/ca/local" | jq '{id, name, root_common_name, intermediate_common_name}'
```

### Export the root certificate as PEM

```bash
curl -fsS "$CADDY_URL/pki/ca/local" \
  | jq -r '.root_certificate' \
  > caddy-local-root.pem
```

### Trust the root cert on the client

- **macOS:** drag `caddy-local-root.pem` into Keychain Access -> System,
  then set "Always Trust" for SSL.
- **Linux (Debian/Ubuntu):**
  ```bash
  sudo cp caddy-local-root.pem /usr/local/share/ca-certificates/caddy-local-root.crt
  sudo update-ca-certificates
  ```
- **Linux (NixOS):** add the PEM to
  `security.pki.certificateFiles = [ ./caddy-local-root.pem ]` and rebuild.
- **Firefox:** Settings -> Privacy & Security -> Certificates -> View
  Certificates -> Authorities -> Import.

## Reload Config from File

`/load` replaces the entire active config atomically. Confirm with the user
first.

```bash
# 1. Pull current config as a baseline
curl -fsS "$CADDY_URL/config/" | jq > current.json

# 2. Edit current.json -> new.json

# 3. Diff to be sure
diff <(jq -S . current.json) <(jq -S . new.json)

# 4. Apply
curl -fsS -X POST -H "Content-Type: application/json" \
  --data-binary @new.json \
  "$CADDY_URL/load"
```

Or via the wrapper:

```bash
bash scripts/caddy.sh reload new.json
```

## Adapt a Caddyfile

The admin API speaks JSON only. To convert a Caddyfile to JSON before posting:

```bash
caddy adapt --config ./Caddyfile --adapter caddyfile --pretty > new.json
```

## Patch a Sub-Section

```bash
# Replace just the http app, leaving tls/pki/etc. untouched
curl -fsS -X PATCH -H "Content-Type: application/json" \
  --data-binary @http-app.json \
  "$CADDY_URL/config/apps/http"
```

## Workflows

### Workflow: Add a new reverse-proxy route

1. Snapshot current config:
   ```bash
   curl -fsS "$CADDY_URL/config/" | jq > current.json
   ```
2. Edit `current.json`, append a route to the right server, e.g.:
   ```json
   {
     "match": [{ "host": ["newapp.lan"] }],
     "handle": [
       {
         "handler": "reverse_proxy",
         "upstreams": [{ "dial": "192.168.1.50:8080" }]
       }
     ]
   }
   ```
3. Diff and apply:
   ```bash
   diff <(jq -S . current.json) <(jq -S . new.json)
   bash scripts/caddy.sh reload new.json
   ```
4. Verify:
   ```bash
   bash scripts/caddy.sh routes | jq '.[] | select(.routes[].match[]?.host[]? == "newapp.lan")'
   ```

### Workflow: Diagnose an upstream that's failing

1. Confirm Caddy sees it as unhealthy:
   ```bash
   curl -fsS "$CADDY_URL/reverse_proxy/upstreams" \
     | jq '.[] | select(.address == "192.168.1.38:8989")'
   ```
2. Hit the upstream directly to confirm it's actually reachable:
   ```bash
   curl -v http://192.168.1.38:8989/
   ```
3. Tail Caddy logs on the LXC (`journalctl -u caddy -f`) for the route in
   question.

### Workflow: Roll back a bad reload

`/load` validates first, so syntactically bad configs don't get applied.
But a config that parses can still break routing. Roll back by reposting
the previous snapshot:

```bash
bash scripts/caddy.sh reload previous-good.json
```

Keep a `current.json` snapshot before every reload for exactly this reason.
