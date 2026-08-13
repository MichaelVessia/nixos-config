# Immich API Troubleshooting

## Authentication

### `401 Unauthorized`

**Cause:** missing or invalid API key, or wrong header name.

**Solution:**

1. Header name is **lowercase** `x-api-key`. Servarr-style apps (Sonarr,
   Radarr, Prowlarr) use `X-Api-Key` — easy to confuse.
2. Verify the key exists in the UI under Account Settings → API Keys.
3. Update `immich_api_key` in `secrets/framework13.yaml` via:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops set secrets/framework13.yaml '["immich_api_key"]' '"<new key>"'
   ```
4. Rebuild home-manager and open a fresh shell so the new value is exported.
5. Sanity check:
   ```bash
   curl -v -H "x-api-key: $IMMICH_API_KEY" "$IMMICH_URL/api/server/ping"
   ```

### `403 Forbidden`

**Cause:** the API key authenticates but lacks the **specific permission**
the endpoint needs. Immich v2 keys carry a granular permission list (e.g.
`asset.read`, `album.write`, `adminUser.read`); not "admin or not".

**Solution:**

1. Identify which scope the endpoint needs from
   `references/api-endpoints.md`. Common ones:
   - `/api/server/statistics`, `/api/server/storage` → `server.read`
   - `/api/admin/users` → `adminUser.read`
   - `/api/users`, `/api/users/me` → `user.read`
   - `/api/assets/*`, `/api/search/*` → `asset.read`
   - `/api/albums/*` → `album.read`
   - `/api/people/*` → `person.read`
   - `/api/jobs` → `job.read`
   - `/api/tags` → `tag.read`
2. Edit the key in the Immich UI (Account Settings → API Keys → pencil
   icon) and tick the missing permission. Save. The same key string keeps
   working with the new scope.
3. If you'd rather start fresh, create a new key with the right scopes,
   put it in sops, and revoke the old one.

### Some commands work, others 403 with the same key

Expected on v2 — see above. The wrapper's `users` sub-command, for example,
tries `/api/admin/users` first and falls back to `/api/users` if the key
lacks `adminUser.read`. That's intentional, not a bug.

## Connection

### `Connection refused` / timeout

**Cause:** Immich isn't running, wrong port, or off-LAN.

**Solution:**

1. From the host: `curl -fsS "$IMMICH_URL/api/server/ping"`.
2. Default port is **2283** (and the bundled stack listens on the same
   port for both the web UI and the API).
3. Check the LXC container (Proxmox):
   ```bash
   pct status 117
   pct exec 117 -- docker ps
   pct exec 117 -- docker logs --tail 50 immich_server
   ```
4. Off-LAN access requires Tailscale or VPN — there's no public ingress.

### `SSL certificate problem`

Internal Immich is served over plain HTTP on the LAN. If you've put it
behind Caddy with a `.lan` cert, either:

- Trust the internal CA (preferred), or
- Use `-k` for a one-off curl. Never bake `-k` into scripts.

## Data / search

### Smart search returns zero results

**Cause:** CLIP embeddings haven't been generated, or the machine-learning
service is down.

**Solution:**

1. Check `bash scripts/immich.sh jobs` for `smartSearch` queue. If
   `waiting > 0`, embeddings are still catching up.
2. Verify ML container is healthy:
   ```bash
   pct exec 117 -- docker ps | grep machine-learning
   pct exec 117 -- docker logs --tail 50 immich_machine_learning
   ```
3. The wrapper's `search` sub-command falls back to filename metadata
   search automatically when smart search returns zero hits, so you'll at
   least get filename matches.

### Metadata search returns wrong fields

Immich's metadata search body schema changes across releases. If the live
response shape disagrees with `references/api-endpoints.md`:

1. Check the pinned OpenAPI spec for the running server version.
2. Update the wrapper's projection rather than guessing — the spec is the
   source of truth.

### `albums [n]` shows fewer than n results

`/api/albums` is unpaginated — it returns every album the caller can see.
The wrapper trims client-side. If you get fewer than `n` it just means
there are fewer than `n` albums (or the API key can't see them — check
`album.read` scope and the calling user's album shares).

### `recent` shows old assets

Immich's `fileCreatedAt` is the EXIF capture date, not the import date.
Phone photos imported today can show 2012 if that's when they were taken.
For "what was imported today", switch the body to `{order:"desc"}` over
`createdAt` instead of `fileCreatedAt` — `POST /api/search/metadata`
accepts that:

```bash
curl -fsS -X POST -H "x-api-key: $IMMICH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"size":25,"order":"desc","orderBy":"createdAt"}' \
  "$IMMICH_URL/api/search/metadata" | jq
```

(Field name may vary by version; consult the OpenAPI spec.)

## Background jobs

### Queue stuck with `waiting > 0` and `active: false`

**Cause:** queue paused, or a dependent service (ML, ffmpeg worker) is
unhealthy.

**Solution:**

1. Check `paused` flag in `bash scripts/immich.sh jobs`.
2. Check container health (see Connection section).
3. To unpause / kick a queue: `PUT /api/jobs/<queue>` with body
   `{"command":"resume","force":false}`. This is a **mutation** — confirm
   with the user before running it.

## Off-LAN access

Immich runs on the LAN only. From a remote machine:

1. Connect Tailscale: `tailscale status` should list the LXC's tailnet
   address.
2. Set `IMMICH_URL` to the MagicDNS hostname (e.g.
   `http://immich.<tailnet>.ts.net:2283`) for the off-LAN session, or
   patch `secrets/framework13.yaml` to use the tailnet address if you
   want it always-on.

## Common error messages

| Error                                | Cause                                              | Solution                                                              |
| ------------------------------------ | -------------------------------------------------- | --------------------------------------------------------------------- |
| `401 Unauthorized`                   | Bad/missing key, wrong header case                 | Verify key in UI, use lowercase `x-api-key`                           |
| `403 Forbidden`                      | Key missing a permission                           | Edit key in UI, tick the needed scope                                 |
| `404 Not Found` on `/api/v1/...`     | Old v1 path                                        | API base is `/api/`, no version segment                               |
| `502 Bad Gateway`                    | Web server up but `immich_server` container down   | `docker logs immich_server` on LXC 117                                |
| Empty `assets.items` from smart search | CLIP embeddings missing or ML service down       | Check `smartSearch` queue + ML container logs                         |
| `connection refused`                 | Service down, wrong port, off-LAN                  | Verify LXC 117, port 2283, Tailscale if off-LAN                       |

## Known limitations

- **Per-permission API keys**: granular and fiddly. Plan key scopes up front.
- **`/api/albums` is unpaginated**: large libraries should expect a big
  response payload (each album includes its owner + sharing metadata).
- **Search relevance**: smart search is CLIP — phrasing matters. "dog
  fetching a ball" works better than "dog".
- **No batch endpoints for most reads**: `assets/{id}` and `people/{id}`
  must be called one at a time.
- **API churn**: minor versions change response shapes. Pin the OpenAPI
  spec to your server version (`v2.5.6` today) and re-verify after upgrade.
