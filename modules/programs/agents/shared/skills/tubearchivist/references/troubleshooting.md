# TubeArchivist API Troubleshooting

## Authentication Issues

### "401 Unauthorized" on a GET

**Cause:** Session expired or jar is missing the `sessionid` cookie.

**Solution:**
1. Re-run the login call to refresh the jar:
   ```bash
   curl -sS -c /tmp/ta.jar -b /tmp/ta.jar \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"username":"'"$TUBEARCHIVIST_USERNAME"'","password":"'"$TUBEARCHIVIST_PASSWORD"'"}' \
     "$TUBEARCHIVIST_URL/api/user/login/"
   ```
2. Verify the jar now contains both `sessionid` and `csrftoken`:
   ```bash
   awk '$6 == "sessionid" || $6 == "csrftoken"' /tmp/ta.jar
   ```
3. The wrapper script handles this automatically — it checks the `sessionid`
   expiry and re-logs in when stale.

### "403 Forbidden" on a POST/PUT/PATCH/DELETE

**Cause:** Django's CSRF middleware rejected the request. Either missing
`X-CSRFToken` header or missing/wrong `Referer`.

**Solution:**
1. Both headers are required for mutations:
   - `X-CSRFToken: <csrftoken cookie value from jar>`
   - `Referer: $TUBEARCHIVIST_URL/` (trailing slash matters — must match
     same-origin)
2. Pull the CSRF value out of the jar correctly:
   ```bash
   CSRF=$(awk '$6 == "csrftoken" { print $7 }' /tmp/ta.jar)
   echo "$CSRF"   # should be a 32-char alphanumeric string
   ```
3. If the cookie jar was just refreshed by a login, the `csrftoken` may
   have rotated — re-read the value before sending the mutation.

### "403 Forbidden" with `CSRF cookie not set`

**Cause:** No jar, or the jar was wiped between login and the mutating
call.

**Solution:** Use the same jar for both `-c` (write) on login and `-b`
(read) on every subsequent call. The wrapper does this by pinning the jar
path to `$TMPDIR/tubearchivist-<uid>/<hash>.jar`.

### Wrong password

**Cause:** Bad credentials.

**Solution:**
1. Verify decrypted secrets:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops -d secrets/framework13.yaml | grep tubearchivist_
   ```
2. Update if needed:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops set secrets/framework13.yaml '["tubearchivist_password"]' '"<new>"'
   ```
3. Rebuild home-manager and open a fresh shell so the new value is exported.
4. The login endpoint returns HTTP 400 (with a JSON error body) on bad
   credentials, not 401.

## Request Shape Issues

### `"missing expected data key"` on subscribe

**Cause:** `POST /api/channel/` requires the `data` envelope.

**Solution:** wrap the payload in `{"data":[{...}]}`:

```json
{ "data": [ { "channel_id": "UCxxxxxxxxxxxxxxxxxxxxxx",
              "channel_subscribed": true } ] }
```

Not just `{"channel_id":"..."}` — that returns HTTP 400.

### "400 Bad Request" with raw text

Inspect the response body — Django REST framework returns a JSON dict of
field errors. The most common ones for `/api/channel/`:

- `channel_id` missing
- `channel_subscribed` missing
- `data` must be a list

## yt-dlp Resolution Issues

### Subscribe task fails with HTTP 404 from `[youtube:tab]`

**Symptom:** The `POST /api/channel/` returns 200, but `GET /api/task/by-name/`
later shows the `subscribe_to` task in `FAILURE` with:

```
ValueError: failed to retrieve URL: ERROR: [youtube:tab] @somehandle:
Unable to download API page: HTTP Error 404: Not Found
```

**Cause:** The handle does not exist on YouTube (typo, renamed channel,
or a guessed handle that was never real). yt-dlp probes the handle and 404s.

**Solution:**
1. Open the URL in a browser to confirm the handle exists.
2. Use the actual canonical handle shown on the channel's YouTube page.
3. Or supply the `UC...` channel ID directly — TA accepts both.

### Subscribe task never finishes

**Cause:** Celery worker stuck or yt-dlp blocked.

**Solution:**
1. Check task list for `STARTED` / `PENDING` entries:
   ```bash
   bash scripts/tubearchivist.sh tasks
   ```
2. Restart the LXC if the worker is wedged:
   ```bash
   pct restart 120   # on the Proxmox host
   ```
3. yt-dlp can be rate-limited by YouTube; check the LXC logs (`journalctl`
   inside the LXC or the TA container logs).

## Connection Issues

### "Could not resolve host" or timeout

**Cause:** Not on the LAN, or LXC 120 is down.

**Solution:**
1. Confirm the LXC is up via Proxmox:
   ```bash
   ssh pve "pct status 120"
   ```
2. Confirm the service responds:
   ```bash
   curl -fsS "$TUBEARCHIVIST_URL/api/health/"
   ```
3. If you're off-LAN, enable Tailscale or VPN. The instance has no public
   route.

### "Connection refused" on the LAN

**Cause:** Service down inside the container.

**Solution:**
1. SSH into the LXC and check service state:
   ```bash
   ssh root@192.168.1.56 systemctl status tubearchivist
   ```
2. Tail the logs:
   ```bash
   ssh root@192.168.1.56 journalctl -u tubearchivist -n 100 --no-pager
   ```

## Storage Issues

### Downloads land but don't show up in `/mnt/synology-media/youtube`

**Cause:** Bind mount or symlink broken inside the LXC.

**Solution:**
1. Inside the LXC, `/youtube` should be a symlink to `/mnt/media/youtube`:
   ```bash
   ssh root@192.168.1.56 ls -la /youtube /mnt/media/youtube
   ```
2. On the Proxmox host, `/mnt/media/youtube` should be bind-mounted from
   `/mnt/synology-media/youtube`. Check the LXC config for the `mp0:`
   entry.
3. If the NAS is unreachable, the bind mount will be present but empty —
   confirm the NAS share is mounted on the host.

## Downloads Stuck

### Queue items in `pending` forever

**Cause:** No new videos detected, or yt-dlp errors.

**Solution:**
1. Check the most recent `download_pending` task:
   ```bash
   bash scripts/tubearchivist.sh tasks | jq '.[] | select(.name | test("download"))'
   ```
2. Trigger a manual rescan from the UI (Settings → Scheduler) or via API:
   ```bash
   CSRF=$(awk '$6 == "csrftoken" { print $7 }' /tmp/ta.jar)
   curl -fsS -b /tmp/ta.jar \
     -H "Content-Type: application/json" \
     -H "X-CSRFToken: $CSRF" \
     -H "Referer: $TUBEARCHIVIST_URL/" \
     -X POST -d '{}' \
     "$TUBEARCHIVIST_URL/api/refresh/"
   ```

## Known Limitations

- **No version field exposed in /api/appsettings/config/.** The version
  string is in `info.version` of `/api/schema/` (OpenAPI).
- **Search endpoint is undocumented in the schema** beyond `200 No
  response body` — the actual response shape is
  `{ queryType, results: { video_results, channel_results,
  playlist_results, fulltext_results } }`. Subject to change.
- **Subscribe is async.** A successful HTTP 200 from `POST /api/channel/`
  only means the task was queued, not that the channel was added.
- **No off-LAN access.** TubeArchivist runs in LXC 120 on Proxmox, only
  reachable via the LAN or Tailscale.

## Common Error Messages

| Status | Body fragment              | Cause                                | Fix                                       |
|--------|----------------------------|--------------------------------------|-------------------------------------------|
| 400    | `missing expected data key`| Wrong subscribe payload shape        | Wrap in `{"data":[...]}`                  |
| 400    | bad credentials            | Wrong username/password              | Re-check sops secret                      |
| 401    | (empty)                    | Session expired                      | Re-login, refresh jar                     |
| 403    | `CSRF`                     | Missing/incorrect CSRF or Referer    | Send `X-CSRFToken` + `Referer: $URL/`     |
| 404    | (HTML)                     | Wrong path; many `/api/...` are not exposed | Check `/api/schema/`                |
| 404    | `[youtube:tab] ... 404`    | yt-dlp couldn't resolve the handle   | Verify the YouTube URL/handle is real     |
