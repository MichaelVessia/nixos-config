# Jellyfin API Troubleshooting

## Authentication Issues

### "401 Unauthorized"
**Cause:** Invalid, missing, or rotated API key.

**Solution:**
1. Open Jellyfin Dashboard → API Keys, delete the bad key, and click
   **+** to generate a new one (give it a descriptive app name).
2. Update `jellyfin_api_key` in `secrets/framework13.yaml`:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops set secrets/framework13.yaml '["jellyfin_api_key"]' '"<new key>"'
   ```
3. Rebuild home-manager (or NixOS) and open a fresh shell so the new value is
   exported by `modules/programs/shell.nix`.
4. Verify:
   ```bash
   curl -v "$JELLYFIN_URL/System/Info" -H "X-Emby-Token: $JELLYFIN_API_KEY"
   ```
5. Header name is `X-Emby-Token` (case-sensitive). `X-Api-Key` will not work
   — Jellyfin inherits the Emby header.

### "403 Forbidden"
**Cause:** The user tied to this API key lacks permission for the endpoint, or
the request was rejected by reverse-proxy auth.

**Solution:**
1. API keys created in Dashboard → API Keys run with admin scope; if you see
   403, check whether the request is hitting Jellyfin directly or being
   intercepted by a reverse proxy (Caddy, Authelia, etc.).
2. Inspect Dashboard → Users → (your user) → permissions if you're using a
   user access token instead of a server API key.

## Connection Issues

### "Connection refused" / timeout
**Cause:** Jellyfin not running, wrong port, or off-LAN with no tunnel.

**Solution:**
1. Confirm the server is up from the LAN:
   ```bash
   curl -fsS "$JELLYFIN_URL/System/Info/Public"
   ```
   (Public endpoint, no auth, good reachability probe.)
2. Default port is `8096` (HTTP) / `8920` (HTTPS).
3. If you're off-network, connect tailscale or VPN — Jellyfin is not exposed
   publicly.
4. Check Docker / systemd logs on the host:
   ```bash
   docker logs jellyfin
   # or
   journalctl -u jellyfin -e
   ```

### "SSL certificate problem"
**Cause:** Self-signed cert or expired Let's Encrypt cert behind a reverse
proxy.

**Solution:**
1. For local testing, use HTTP (`http://192.168.1.21:8096`) instead of HTTPS.
2. For curl debugging only, `-k` skips verification. Don't ship scripts that
   depend on `-k`.
3. Renew or import the proxy's cert into the system trust store.

## Item Endpoints Return Empty

### `/Users/{userId}/Items` returns `[]` for a query you know matches

**Cause #1:** The user id is restricted and can't see that library.

**Solution:** Use an admin user id. The wrapper's `pick_user_id` picks the
first non-disabled user; you may need to pick the admin explicitly:

```bash
USER_ID=$(curl -s "$JELLYFIN_URL/Users" \
  -H "X-Emby-Token: $JELLYFIN_API_KEY" \
  | jq -r '[.[] | select(.Policy.IsAdministrator)] | .[0].Id')
```

**Cause #2:** Missing `Recursive=true`.

**Solution:** Search across the whole library requires `Recursive=true`.
Without it, you only search the top-level library node.

**Cause #3:** Encoded query has a trailing newline.

**Solution:** Use `jq -rn --arg v "$1" '$v|@uri'` (the wrapper does this).
`jq -sRr @uri <<<"$1"` leaves a trailing `%0A` and breaks the search term.

### `/Users/{userId}/Items/Latest` returns fewer items than expected

**Cause:** `Latest` is per-library by default. Without `GroupItems=false` it
groups episodes under their series. Combine with `Limit` and `IncludeItemTypes`
to control the shape.

## Scheduled Tasks

### `run-task` returns 204 but nothing happens
**Cause:** Task already running, or another task is blocking the queue.

**Solution:**
1. Check state:
   ```bash
   bash scripts/jellyfin.sh scheduled-tasks | jq '.[] | select(.id == "<id>")'
   ```
2. `State: "Running"` means it's already in flight. `Idle` after a fresh POST
   means the task completed quickly (some are instant).

### Task fails repeatedly
**Cause:** Permission issue on the mounted media path, or missing dependency
(e.g. ffmpeg for chapter detection).

**Solution:**
1. Check Dashboard → Logs for the latest task log.
2. Verify media mount permissions (`/mnt/media/...`).
3. Confirm `ffmpeg` is bundled with the Jellyfin image you're running.

## Sessions

### Session list has stale entries
**Cause:** Clients that disconnected without a clean logout linger for ~10
minutes.

**Solution:**
1. Filter by recent activity:
   ```bash
   curl -s "$JELLYFIN_URL/Sessions" \
     -H "X-Emby-Token: $JELLYFIN_API_KEY" \
     | jq '[.[] | select(.LastActivityDate > (now - 600 | strftime("%Y-%m-%dT%H:%M:%S")))]'
   ```
2. `NowPlayingItem` is the reliable signal for "actually watching right now".

### `now-playing` shows no items even though someone is watching
**Cause:** Some clients (older Chromecast Android, some Roku builds) don't
report playback state to the server promptly.

**Solution:**
1. Wait 30s and retry — most clients catch up.
2. Check from the client UI whether the playback is going through Jellyfin or
   a direct file share (SMB / DLNA bypass it).

## Library Stats

### `MovieCount` / `SeriesCount` is zero
**Cause:** Library scan never completed, or root paths aren't mounted.

**Solution:**
1. Check Dashboard → Libraries → (library) → Scan.
2. Confirm mounts:
   ```bash
   bash scripts/jellyfin.sh libraries
   ```
   Each `locations` entry must exist and be readable by the Jellyfin process.
3. Trigger a scan via the `RefreshLibrary` scheduled task.

## Known Limitations

- **No bulk operations:** Most write endpoints are one-item-at-a-time.
- **Auth header drift:** `X-Emby-Token` is the canonical name; older docs may
  show `X-Emby-Authorization`. Stick to `X-Emby-Token` for API keys.
- **No native API key rotation:** You must delete and recreate; no rotate-in-
  place. Update sops afterwards.
- **Off-LAN access:** Not exposed publicly. Use tailscale / WireGuard.

## Common Error Messages

| Error                                              | Cause                              | Solution                                              |
| -------------------------------------------------- | ---------------------------------- | ----------------------------------------------------- |
| `401 Unauthorized`                                 | Bad / missing API key              | Regenerate in Dashboard → API Keys, rotate via sops   |
| `404 Not Found`                                    | Wrong path (case matters)          | Endpoints are PascalCase: `/System/Info`, not `/system/info` |
| `Connection refused`                               | Server down or wrong host:port     | Verify with `/System/Info/Public`                     |
| Empty `Items` array on a search you know matches   | Restricted user, missing Recursive, or trailing `%0A` in query | Use admin user id, set `Recursive=true`, encode with `jq -rn` |
| `204 No Content` from `run-task`                   | Expected — task was queued         | Poll `/ScheduledTasks` to see state                   |

## Debug Mode

1. Dashboard → Logs — live log view.
2. Set log level in `system.xml` (`<LogLevel>Debug</LogLevel>`), restart.
3. Logs land in `/config/log/` (Docker) or the per-user data dir on bare
   metal.
