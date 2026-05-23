# Caddy Admin API Troubleshooting

## Reachability

### "Connection refused" or timeout on `$CADDY_URL`

**Cause:** admin API isn't listening, host firewall blocks port 2019, or you're
off-LAN.

**Solution:**

1. From the Caddy host itself:
   ```bash
   curl -fsS http://127.0.0.1:2019/config/ | jq 'keys'
   ```
   If that works, the issue is network reachability, not Caddy.
2. Confirm the admin listener:
   ```bash
   curl -fsS "$CADDY_URL/config/admin" | jq
   ```
   Expected: `{"listen": ":2019"}` or similar. If empty, the admin endpoint
   may be disabled in the config (`"admin": {"disabled": true}`).
3. Off-LAN? Connect via tailscale/VPN. The admin port is intentionally not
   exposed past the LAN.
4. NixOS LXC firewall: ensure
   `networking.firewall.allowedTCPPorts` includes `2019` if calls are
   coming from outside the host.

### `CADDY_URL not set`

**Cause:** sops-nix secret didn't get exported into the shell.

**Solution:**

1. Verify the secret is decrypted on the host:
   ```bash
   ls /run/secrets/caddy_url && sudo cat /run/secrets/caddy_url
   ```
2. Check `modules/programs/shell.nix` exports it (look for a
   `[ -f "$SECRETS_DIR/caddy_url" ]` line).
3. Open a fresh shell — env vars set by `shell.nix` only apply to new shells.
4. Confirm: `echo "$CADDY_URL"`.

### "Forbidden" / "Access Denied" from admin API

**Cause:** Caddy's `admin.origins` allowlist doesn't include the caller's
origin. The admin API by default accepts requests from loopback/link-local
only; this Caddy is configured to also accept LAN.

**Solution:**

1. Check the current admin config:
   ```bash
   curl -fsS "$CADDY_URL/config/admin" | jq
   ```
2. If `origins` is set, ensure your client's IP/hostname is in the list.
3. If you're hitting via a non-standard `Host:` header, add it to
   `admin.origins` and reload.

## Config / Reload Failures

### `POST /load` returns 400 with an error

**Cause:** the new config failed validation. Caddy keeps the previous
config running and returns an error body describing what's wrong.

**Solution:**

1. Read the response body literally — Caddy points at the bad path:
   ```bash
   curl -fsS -X POST -H "Content-Type: application/json" \
     --data-binary @new.json "$CADDY_URL/load"
   # e.g. "loading new config: ... unknown module: http.handlers.foo"
   ```
2. Common causes:
   - Misspelled `handler`/`module` name.
   - Required field missing on a handler (e.g. `upstreams` on
     `reverse_proxy`).
   - JSON schema mismatch — check
     https://caddyserver.com/docs/json/ for the exact shape.
3. Validate offline first if you have the `caddy` binary handy:
   ```bash
   caddy validate --config new.json --adapter json
   ```

### Reload "succeeds" but the new route doesn't work

**Cause:** config parsed but is semantically wrong (e.g. matcher never
fires, route under the wrong server, listener port mismatch).

**Solution:**

1. Re-fetch the active config and confirm the new route is actually there:
   ```bash
   curl -fsS "$CADDY_URL/config/" | jq '.apps.http.servers'
   ```
2. Tail Caddy logs on the LXC: `journalctl -u caddy -f` and hit the route
   to see how it's being matched.
3. Watch for `srv0` vs `srv1` — routes under the wrong server won't fire
   on the listener you expect.

### Need to roll back

```bash
bash scripts/caddy.sh reload previous-good.json
```

Always snapshot `current.json` before a reload.

## Certificates / Internal CA

This Caddy issues certs via its built-in CA (`tls.automation.issuers.module =
internal`). That means **clients must trust Caddy's root CA** or every
`https://*.lan` request shows a browser warning / fails curl without `-k`.

### Browser shows "NET::ERR_CERT_AUTHORITY_INVALID" on `.lan`

**Cause:** client doesn't trust Caddy's internal CA root cert.

**Solution:**

1. Export the root cert:
   ```bash
   curl -fsS "$CADDY_URL/pki/ca/local" \
     | jq -r '.root_certificate' > caddy-local-root.pem
   ```
2. Install into the client's trust store (see
   `quick-reference.md#trust-the-root-cert-on-the-client` for per-OS steps).
3. Restart the browser. Firefox uses its own trust store and needs an
   explicit Authorities import.

### `curl` fails with "SSL certificate problem: unable to get local issuer certificate"

**Cause:** same — system trust store doesn't include Caddy's root.

**Solution:**

- Quick local test: `curl -k https://...` (skip verification).
- Proper fix: install the root cert as above so other clients work too.

### Caddy isn't issuing certs at all

**Cause:** TLS automation policy missing or no `issuers` configured.

**Solution:**

1. Check policies:
   ```bash
   curl -fsS "$CADDY_URL/config/apps/tls/automation" | jq
   ```
2. Confirm an `issuers` array with `{"module": "internal"}` (for LAN domains)
   or `{"module": "acme"}` (for public domains).
3. Confirm the route's host matches a policy's `subjects` (or that the
   policy has no `subjects`, meaning it applies to everything).

### Certificate rotation / clearing storage

Caddy stores certs in its data directory (often `/var/lib/caddy`). To force
re-issuance, stop Caddy, remove the cert under
`certificates/local/<sanitized-host>/`, and restart. Don't do this casually;
it's almost never needed.

## Upstream / Routing Issues

### `bash scripts/caddy.sh routes` shows a host but requests 502

**Cause:** Caddy is reaching the upstream but the upstream is returning an
error, or the upstream isn't actually reachable from the Caddy host.

**Solution:**

1. Check live upstream health:
   ```bash
   curl -fsS "$CADDY_URL/reverse_proxy/upstreams" | jq
   ```
   Look for `fails > 0` on the upstream in question.
2. From the Caddy LXC, curl the upstream directly:
   ```bash
   curl -v http://192.168.1.38:8989/
   ```
3. Check the upstream's own logs for the failing request.

### Route exists but matcher never fires

**Cause:** `match` ordering, missing `host` matcher, or wrong `srv*`.

**Solution:**

1. Print all matchers for the server that owns the listener:
   ```bash
   curl -fsS "$CADDY_URL/config/" | jq '.apps.http.servers.srv0.routes[].match'
   ```
2. Remember: routes are evaluated top-to-bottom; a broader earlier matcher
   can absorb requests meant for a later one. Reorder or tighten the
   matcher.
3. Use `Host:` header tests:
   ```bash
   curl -v -H "Host: newapp.lan" https://192.168.1.252/ -k
   ```

## Known Limitations

- **Admin API has no auth.** Don't expose port 2019 off-LAN.
- **JSON-only.** Caddyfile must be adapted via `caddy adapt` before posting
  to `/load`.
- **Atomic replacement.** `/load` swaps the whole config; `/config/<path>`
  PATCH for partial updates.
- **Persistence:** the running config is in-memory. If Caddy is started
  with `--config` on disk, that file is the source of truth at next boot;
  reload via `/load` does **not** rewrite that file. To make changes
  persist across restarts, also update the on-disk config (or rely on the
  NixOS module's config).

## Common Error Messages

| Error                                                | Cause                              | Solution                                                                 |
| ---------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------ |
| `Connection refused`                                 | Caddy down or wrong host           | Check `systemctl status caddy` on the LXC                                |
| `unknown module: http.handlers.foo`                  | Typo in handler name               | Check https://caddyserver.com/docs/modules/                              |
| `loading TLS app: ... no matching policy`            | Host not covered by any TLS policy | Add a policy with the right `subjects` or remove `subjects` to catch all |
| `tls: failed to verify certificate: x509: ...`       | Client doesn't trust internal CA   | Install root cert from `/pki/ca/local`                                   |
| `502 Bad Gateway`                                    | Upstream unreachable / erroring    | Curl upstream from Caddy host; check upstream logs                       |
| `Forbidden` on admin API                             | `admin.origins` doesn't allow you  | Update `admin.origins`, reload                                           |

## Debug

- Caddy logs on the host: `journalctl -u caddy -f`
- Increase log verbosity by adding to the config:
  ```json
  "logging": { "logs": { "default": { "level": "DEBUG" } } }
  ```
  Then `POST /load`. Remember to revert; DEBUG is noisy.
- Admin API endpoint docs: https://caddyserver.com/docs/api
