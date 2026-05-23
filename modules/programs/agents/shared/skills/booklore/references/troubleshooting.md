# BookLore API Troubleshooting

## Authentication issues

### "401 Unauthorized" on `/auth/login`

**Cause:** Bad credentials.

**Solution:**
1. Confirm what's stored:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops -d --extract '["booklore_username"]' secrets/framework13.yaml
   ```
2. If wrong, rotate via sops:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops set secrets/framework13.yaml '["booklore_password"]' '"<new password>"'
   ```
3. Rebuild home-manager and open a fresh shell so the new value is
   exported into `BOOKLORE_PASSWORD`.
4. Re-test:
   ```bash
   curl -v -X POST -H "Content-Type: application/json" \
     -d "{\"username\":\"$BOOKLORE_USERNAME\",\"password\":\"$BOOKLORE_PASSWORD\"}" \
     "$BOOKLORE_URL/api/v1/auth/login"
   ```

### "401 Unauthorized" on a regular endpoint after a previously good login

**Cause:** Access token expired (JWTs are short-lived) or the server
restarted and invalidated tokens.

**Solution:**
- Easiest: blow away the cached token and re-run:
  ```bash
  rm -rf "${TMPDIR:-/tmp}/booklore-$(id -u)"
  bash scripts/booklore.sh status
  ```
- If you're working with a stashed `$TOKEN`, log in again and re-stash.
- Or, if `/api/v1/auth/refresh` exists on this build, exchange the refresh
  token (see `api-endpoints.md`).

### HTTP 400 on `/auth/login` with "Duplicate entry ... for key 'uq_refresh_token'"

**Cause:** Known server bug in the deployed `development` build. The JWT's
`iat` claim has second-level resolution, so two logins in the same wall
clock second produce identical refresh tokens, which violates a UNIQUE
constraint on `refresh_token`.

**Solution:**
- The wrapper avoids this by caching the access token until its `exp`
  passes. If you're hand-rolling curl, either wait > 1 second between
  logins, or stash and reuse the token.
- Long-term fix is upstream: add nanosecond resolution to `iat` or make
  the unique constraint tolerate replay within a second.

### "403 Forbidden"

**Cause:** Authenticated, but the user lacks permission for that
endpoint.

**Solution:**
1. Check the logged-in user's permissions:
   ```bash
   bash scripts/booklore.sh me
   ```
2. Promote the user (or use an admin account) via the BookLore UI.

## Connection issues

### "Connection refused" / timeout

**Cause:** BookLore not running, wrong host/port, or the LAN host is
unreachable from this machine.

**Solution:**
1. Ping the host:
   ```bash
   curl -fsS "$BOOKLORE_URL" -o /dev/null -w "%{http_code}\n"
   ```
2. Confirm the LXC/container is up. From the Proxmox host:
   ```bash
   pct status 100
   pct exec 100 -- systemctl status booklore
   ```
3. Off-LAN: bring up Tailscale / VPN; `192.168.1.7` is not routable from
   the open internet.

### "SSL certificate problem"

**Cause:** Reverse proxy with a self-signed cert.

**Solution:**
1. For local testing: `curl -k ...`
2. Long term: install a proper cert (Caddy / Traefik / nginx-acme).

## 404 Not Found

### Endpoint truly doesn't exist on this deployment

The deployed instance reports `version: "development"` and is older than
upstream `main`. Several intuitive paths return 404:

| Tried             | Use instead         |
|-------------------|---------------------|
| `/api/v1/library` | `/api/v1/libraries` |
| `/api/v1/shelf`   | `/api/v1/shelves`   |
| `/api/v1/healthcheck` | `/api/v1/version`|

If something else 404s, don't assume it's a bug — verify which
controllers are compiled into the running JAR.

### Recipe: list installed controllers

From a host that can `ssh` into the Proxmox node hosting the BookLore
LXC (CTID 100 in this setup):

```bash
# All Controller classes shipped in the BookLore JAR
ssh proxmox 'pct exec 100 -- find /opt/booklore -name "*Controller*.class"'

# Or, if BookLore is packaged as a fat jar, peek inside it:
ssh proxmox 'pct exec 100 -- sh -c "cd /opt/booklore && \
  unzip -l app.jar | grep -i Controller"'
```

The class names map roughly to URL prefixes (`AuthController` →
`/api/v1/auth/...`, `BookController` → `/api/v1/books/...`, etc.). If
there's no `RefreshController` or no `refresh` method in `AuthController`,
that endpoint isn't there.

### Confirm a single endpoint is missing vs. broken

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" \
  "$BOOKLORE_URL/api/v1/auth/refresh"
# 404 — endpoint doesn't exist
# 401 — endpoint exists but requires different auth
# 405 — wrong HTTP method
# 500 — server error, check logs
```

## Server errors

### "500 Internal Server Error"

**Cause:** Bug, bad input, or DB issue on the server.

**Solution:**
1. Tail BookLore logs on the host:
   ```bash
   ssh proxmox 'pct exec 100 -- journalctl -u booklore -n 200 --no-pager'
   ```
2. Reproduce with a minimal request and copy the stack trace.

### Empty response / hang

**Cause:** Long-running scan or large `/books` payload.

**Solution:**
1. Time the call: `time curl -fsS ... > /dev/null`
2. For `/books`, slice client-side with `jq '.[:N]'` rather than fetching
   into a TUI.

## Known limitations

- **No server-side book search confirmed.** The wrapper filters on the
  client. For very large libraries this is wasteful — verify whether a
  search endpoint exists before scaling up.
- **No on-disk token cache.** Each invocation does one extra login HTTP
  call. Fine for interactive use, not for tight loops.
- **No mutations exposed by the wrapper.** Adding, editing, or deleting
  books / shelves / libraries must be done via the UI or hand-rolled curl,
  and the endpoint must be verified first.
- **`version: "development"`.** Don't trust upstream docs blindly; verify
  endpoints against this deployment.

## Common error patterns

| Symptom                                        | Likely cause                          | Fix                                   |
|------------------------------------------------|---------------------------------------|---------------------------------------|
| `accessToken` is `null` from login             | Wrong username/password               | Rotate via sops, re-source env        |
| 401 on every call after some time              | Token expired                         | Re-login (the wrapper does this)      |
| 404 on a plausible path                        | Endpoint not in this build            | Check controllers (see recipe above)  |
| `jq: error: Cannot iterate over null`          | Endpoint returned an object, not list | Inspect raw JSON before piping to jq  |
| `curl: (7) Failed to connect`                  | Host down / off-LAN                   | Verify reachability, bring up VPN     |
