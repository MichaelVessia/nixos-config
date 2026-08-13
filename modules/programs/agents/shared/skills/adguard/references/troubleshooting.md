# AdGuard Home Troubleshooting

## Authentication issues

### "401 Unauthorized"

**Cause:** Wrong username or password.

**Solution:**

1. Check the live values:
   ```bash
   echo "$ADGUARD_USERNAME"
   # don't echo the password to logs, but confirm it's set:
   [ -n "$ADGUARD_PASSWORD" ] && echo "password is set" || echo "password missing"
   ```
2. AdGuard stores user credentials **bcrypt-hashed** inside its own
   `AdGuardHome.yaml` (`users:` list). There is no UI for password rotation
   and no API endpoint that takes a plaintext password and writes the hash
   for you. To rotate:
   - SSH into the LXC: `ssh root@192.168.1.109` (or via Tailscale).
   - Generate a bcrypt hash:
     ```bash
     htpasswd -bnBC 10 "" "newpassword" | tr -d ':\n'
     ```
     (or `python3 -c 'import bcrypt; print(bcrypt.hashpw(b"newpassword", bcrypt.gensalt(10)).decode())'`)
   - Edit `/etc/adguardhome/AdGuardHome.yaml` (or wherever your install
     keeps it — confirm with `systemctl cat AdGuardHome`):
     ```yaml
     users:
       - name: <username>
         password: $2a$10$....bcrypt-hash....
     ```
   - Restart: `systemctl restart AdGuardHome`.
   - Update the sops secret on the workstation:
     ```bash
     SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
       sops set ~/nixos-config/secrets/framework13.yaml \
       '["adguard_password"]' '"newpassword"'
     ```
   - Rebuild home-manager and open a fresh shell.
3. If you only need to **remove** a user (e.g. lost password), delete its
   entry from `users:` in `AdGuardHome.yaml`, restart, and add a new one.

### "403 Forbidden"

**Cause:** Either AdGuard's `allowed_clients` / `disallowed_clients`
restrictions (see Settings → DNS settings → Access settings) are blocking
your source IP, or a reverse proxy in front of AdGuard is rejecting the
request.

**Solution:**

1. Hit AdGuard directly on its LAN IP/port (`http://192.168.1.109`) and
   bypass any proxy.
2. Check current access lists:
   ```bash
   curl -s -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
     "$ADGUARD_URL/control/access/list"
   ```
3. Verify reverse proxy (Caddy/Nginx) isn't stripping the Authorization
   header.

## Connection issues

### "Connection refused" / timeout

**Cause:** AdGuard isn't running, isn't listening on the expected HTTP port,
or the LXC is down.

**Solution:**

1. Ping the host: `ping 192.168.1.109`.
2. Check the service over SSH:
   ```bash
   ssh root@192.168.1.109 'systemctl status AdGuardHome'
   ```
3. Confirm the HTTP port from `AdGuardHome.yaml`:
   ```yaml
   http:
     address: 0.0.0.0:80
   ```
   If you changed it, update `adguard_url` in sops.
4. Check logs: `journalctl -u AdGuardHome -n 100`.

### "SSL certificate problem"

If you front AdGuard with HTTPS via Caddy:

1. For testing only: `curl -k ...`.
2. Verify the cert in Caddy is current and the hostname matches.
3. Bypass the proxy entirely (use `http://<lxc-ip>`) to confirm AdGuard
   itself is fine.

## DNS-side issues

### AdGuard reports running but DNS queries fail

**Cause:** AdGuard's HTTP API is healthy but the DNS listener on `:53` died
or never bound (port conflict with `systemd-resolved`, `dnsmasq`,
`unbound`, etc.).

**Solution:**

1. From the workstation: `dig @192.168.1.109 example.com`. If it hangs or
   returns SERVFAIL, the DNS side is broken even though `/control/status`
   says `running: true`.
2. SSH in and check `ss -lnup | grep ':53'` — only one process should be
   bound.
3. Typical culprit on Debian/Ubuntu LXCs is `systemd-resolved`. Disable it:
   ```bash
   systemctl disable --now systemd-resolved
   ```
   Then restart AdGuard.
4. Re-verify: `dig @192.168.1.109 doubleclick.net` should return AdGuard's
   blocking IP (or NXDOMAIN, depending on `blocking_mode`).

### Clients still seeing ads after enabling protection

**Cause:** DNS not actually pointed at AdGuard.

**Solution:**

1. On the client: `nslookup doubleclick.net` — answer should match AdGuard's
   blocking response, not a real IP.
2. Check what resolver the client is actually using (router DHCP options,
   per-device DNS overrides, DoH built into the browser).
3. Browsers with Secure DNS / DoH bypass system DNS entirely. Disable DoH
   in Chrome/Firefox/Safari or set them to use AdGuard as the DoH provider.

### Block list never updates

**Cause:** Outbound HTTPS broken (DNS bootstrap loop) or the list URL is
404ing.

**Solution:**

1. From the LXC: `curl -I <filter url>`.
2. Check `bootstrap_dns` in `/control/dns_info` — these must resolve
   without needing AdGuard itself.
3. Manual refresh:
   ```bash
   curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
     -H "Content-Type: application/json" \
     -d '{"whitelist": false}' \
     "$ADGUARD_URL/control/filtering/refresh"
   ```
4. After the refresh, `filters[].last_updated` should be a recent timestamp
   and `rules_count > 0`.

## Mutation issues

### `POST /control/protection` returns 400

**Cause:** Body shape changed between versions. v0.107.x expects
`{"enabled": <bool>, "duration": <ms>}`. Older releases accepted just
`{"enabled": <bool>}`.

**Solution:** Always include `duration`. `0` means "until manually
re-enabled".

### Protection re-enables on its own

**Cause:** A previous `duration` (in ms) is still counting down.

**Solution:** Send `{"enabled": true, "duration": 0}` to clear the timer,
then disable again with `duration: 0` if you want it off indefinitely.

## Performance issues

### `/control/querylog` is slow or returns huge payloads

**Cause:** Query log size grew large or `limit` wasn't set.

**Solution:**

1. Always pass `?limit=<n>` (the wrapper defaults to 50).
2. Use `?search=<substr>` server-side instead of grepping client-side.
3. Trim retention: Settings → General → Query log → "Query log retention".
4. Last resort, clear it:
   ```bash
   curl -s -X POST -u "$ADGUARD_USERNAME:$ADGUARD_PASSWORD" \
     "$ADGUARD_URL/control/querylog_clear"
   ```

## Known quirks

- **`/control/clients/find` param naming**: it's `ip0`, `ip1`, ..., not
  `ip`. Plain `?ip=` silently returns `[]` instead of erroring.
- **`top_*` lists are arrays of single-key objects**, not `{domain: count}`
  maps. Iterate with `keys[0]` and the corresponding value.
- **`elapsedMs` in querylog is a string**, not a number. Cast with `tonumber`
  if you want to filter on it.
- **`duration` on the protection toggle is milliseconds**, not seconds.
- **`http_port` in `/control/status` defaults to `80`** on a fresh install —
  don't confuse it with `dns_port: 53`.

## Common error messages

| Error | Cause | Fix |
| --- | --- | --- |
| `401 Unauthorized` | wrong basic auth | rotate bcrypt hash in `AdGuardHome.yaml`, see above |
| `403 Forbidden` | access list or proxy | check `/control/access/list`, bypass proxy |
| `404 Not Found` | wrong path | base path is `/control`, not `/api` |
| `Connection refused` | service down or wrong port | `systemctl status AdGuardHome` |
| `bind: address already in use` (logs) | another resolver on `:53` | disable `systemd-resolved` |
| `cert signed by unknown authority` | self-signed reverse proxy | use HTTP on LAN or fix the cert |
