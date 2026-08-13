# Jellyseerr API Troubleshooting

## Authentication Issues

### "401 Unauthorized"
**Cause:** Invalid, missing, or expired API key, or wrong header name.

**Solution:**
1. Get the current key from Settings → General → API Key (Jellyseerr UI).
2. Rotate it in sops:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops set secrets/framework13.yaml '["jellyseerr_api_key"]' '"<new key>"'
   ```
3. Rebuild home-manager (`home-manager switch` or your flake's rebuild
   target) and open a fresh shell so the new value is exported.
4. Verify:
   ```bash
   curl -v "$JELLYSEERR_URL/api/v1/status" -H "X-Api-Key: $JELLYSEERR_API_KEY"
   ```
5. Header name is `X-Api-Key` (case-insensitive on the wire, but match the
   case in scripts for clarity). Sending it as `Authorization: Bearer` will
   not work.

### "403 Forbidden"
**Cause:** API key belongs to a user that lacks the required permission, or
the endpoint requires a logged-in user session (cookies) rather than the
service key.

**Solution:**
1. Endpoints like `POST /request` (creating a new request), `POST /issue`
   (filing an issue), and vote endpoints require a real user session, not the
   service API key. Use the Jellyseerr web UI for those.
2. For admin-only endpoints (`/user`, settings), make sure the API key is
   owned by an Admin in Settings → Users.
3. If you recently changed a user's permissions, restart Jellyseerr so the
   permission cache refreshes.

### Key works in browser but not from script
**Cause:** Shell did not pick up the exported env vars yet.

**Solution:**
1. Confirm with `echo "${JELLYSEERR_URL:?}" "${JELLYSEERR_API_KEY:0:6}…"`.
2. If empty, open a fresh shell — sops-nix exports happen in the rc file
   (see `modules/programs/shell.nix`).
3. Confirm the secret file exists:
   `ls -l /run/secrets/jellyseerr_url /run/secrets/jellyseerr_api_key`.
4. If running over SSH non-interactively, source the secrets explicitly:
   ```bash
   export JELLYSEERR_URL=$(cat /run/secrets/jellyseerr_url)
   export JELLYSEERR_API_KEY=$(cat /run/secrets/jellyseerr_api_key)
   ```

## Connection Issues

### "Connection refused" / `ECONNREFUSED`
**Cause:** Jellyseerr container not running, wrong port, or wrong host.

**Solution:**
1. Hit it from the host:
   `curl -v "$JELLYSEERR_URL/api/v1/status"` — TCP-level failure means the
   service is down or the port is wrong.
2. Default port is `5055`. Confirm the live URL is `http://192.168.1.83:5055`.
3. Check the container/service: `docker ps | grep jellyseerr` or
   `systemctl status jellyseerr` depending on how it's hosted.
4. Inspect logs (`docker logs jellyseerr` or the systemd journal) for
   startup errors (DB migrations, port conflicts).

### "Could not resolve host"
**Cause:** DNS or hostname typo.

**Solution:**
1. The default URL uses an IP (`192.168.1.83`), so DNS shouldn't matter on
   LAN. If you switched to a hostname, confirm it resolves: `getent hosts <name>`.
2. Reset to the IP form via sops if the hostname isn't reliable.

### Off-LAN access (no response from outside the network)
**Cause:** Jellyseerr binds to the LAN only.

**Solution:**
1. Connect via tailscale (preferred) — the same `192.168.1.83:5055` URL
   works once tailscale is up because the host is on the tailnet.
2. Or expose via the reverse proxy (Caddy) on a public hostname, but only if
   you've enabled auth in front of it. Direct exposure of `/api/v1` to the
   internet is a bad idea.
3. If using the Caddy URL, update `jellyseerr_url` in sops to the public URL
   *and* make sure the API key still works on that path (some reverse-proxy
   setups strip headers — verify with
   `curl -v https://<public>/api/v1/status -H "X-Api-Key: $JELLYSEERR_API_KEY"`).

### Slow first request after idle
**Cause:** Jellyseerr lazily reconnects to TMDB / Jellyfin on cold start.

**Solution:**
1. Treat the first call after a long idle as a warmup; retry once.
2. Increase the curl timeout if scripting: `curl --max-time 30 …`.

## Request / Approval Issues

### `approve` returns 500
**Cause:** The linked Sonarr/Radarr can't accept the request (missing root
folder, quality profile, or indexer).

**Solution:**
1. Verify the *arr is healthy via its own skill (`bash scripts/sonarr.sh status`).
2. In Jellyseerr Settings → Services, re-test the Sonarr/Radarr connection
   and confirm `Default Quality Profile` and `Default Root Folder` are set
   per server.
3. Check Jellyseerr logs for the underlying error
   (`docker logs jellyseerr | tail -100`).
4. Re-approve once the underlying service is fixed.

### Approval succeeds but nothing downloads
**Cause:** Sonarr/Radarr accepted the add but the indexers returned nothing
or the download client is offline.

**Solution:**
1. In the *arr: check Activity → Queue and System → Tasks.
2. From the agent: `bash scripts/sonarr.sh queue` (or the radarr equivalent).
3. Confirm indexers and download client health.
4. Re-trigger a search manually from the *arr or its skill.

### "Request already exists"
**Cause:** A previous request for the same media is still pending or
approved.

**Solution:**
1. Look it up with the search endpoint and check `mediaInfo.status`.
2. Delete or decline the stale duplicate before re-requesting.

## Media Issues

### `media-status <id>` returns 404
**Cause:** `mediaId` is Jellyseerr's internal ID, not the TMDB ID.

**Solution:**
1. Search first: `bash scripts/jellyseerr.sh search "<title>"` — the
   `mediaInfo.id` field on a result is the Jellyseerr id.
2. Or list requests: `bash scripts/jellyseerr.sh requests --all` and use
   `.media.id` from a request.

### Recently-added list is empty
**Cause:** Jellyseerr hasn't synced from Jellyfin recently, or no items are
in the `available` state.

**Solution:**
1. Trigger a Jellyfin sync via the Jellyseerr UI: Settings → Jobs & Cache
   → "Jellyfin Full Library Scan".
2. Verify the linked Jellyfin server is reachable
   (`curl -s "$JELLYFIN_URL/System/Info/Public" | jq`).

## User / Issue Endpoints

### `users` returns 403
**Cause:** API key user is not an Admin.

**Solution:**
1. In the UI, edit the user that owns the key and grant Admin permission, or
   create a dedicated service user with Admin permission and rotate the key
   into sops as above.

### Open issues list is empty even though users reported things
**Cause:** All issues were closed, or filter is wrong.

**Solution:**
1. Try `filter=all`:
   `curl -s "$JELLYSEERR_URL/api/v1/issue?filter=all" -H "X-Api-Key: $JELLYSEERR_API_KEY" | jq`.
2. Confirm the user actually submitted the issue against the media (not as a
   Discord message).

## Debug Mode

Enable debug logs for detailed errors:

1. Settings → Logs → Log Level → `debug`.
2. Reproduce the failing call.
3. Tail logs: `docker logs -f jellyseerr` (or wherever the deployment lives).
4. Filter for `[API]` / `[Auth]` lines.

## Common Error Messages

| Error                               | Cause                                  | Fix                                                                |
| ----------------------------------- | -------------------------------------- | ------------------------------------------------------------------ |
| `401 Unauthorized`                  | Bad/missing API key                    | Rotate key via sops, open fresh shell                              |
| `403 Forbidden`                     | Key lacks permission / wrong auth type | Admin the user, or use UI for user-session endpoints               |
| `404 Not Found` on `media-status`   | Used TMDB id instead of mediaId        | Search first, use `mediaInfo.id`                                   |
| `500` on `approve`                  | Linked *arr misconfigured              | Re-test service in Jellyseerr settings                             |
| `ECONNREFUSED`                      | Service down or wrong host             | `docker ps`, check logs, confirm URL                               |
| Empty `results` on `search`         | TMDB returned nothing                  | Try alternate spelling / native title                              |
| Empty `results` on `recently-added` | Jellyfin sync stale                    | Run "Jellyfin Full Library Scan" job                               |
