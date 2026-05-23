# Prowlarr API Troubleshooting

## Authentication Issues

### "401 Unauthorized"
**Cause:** Invalid or missing API key.

**Solution:**
1. Get API key from Settings → General → Security → API Key.
2. Update `prowlarr_api_key` in `secrets/framework13.yaml` via:
   `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops set secrets/framework13.yaml '["prowlarr_api_key"]' '"<new key>"'`
3. Rebuild home-manager and open a fresh shell so the new value is exported.
4. Verify: `curl -v "$PROWLARR_URL/api/v1/system/status" -H "X-Api-Key: $PROWLARR_API_KEY"`.
5. Header name is `X-Api-Key` (case-sensitive).

### "403 Forbidden"
**Cause:** Authentication mode disabled or API access restricted.

**Solution:**
1. Settings → General → Security → Authentication.
2. Ensure "Authentication" is not set to "Disabled" (counterintuitive but
   `Disabled` removes the API too).
3. Check IP-based restrictions if you have any in front of Prowlarr (Caddy,
   nginx, Cloudflare).

### Variables not exported

**Symptom:** `PROWLARR_URL not set` from the wrapper.

**Solution:**
1. Confirm secrets are activated: `ls /run/secrets/prowlarr_*` should list two
   files (NixOS) or check `~/.config/sops-nix/secrets/` on macOS.
2. Confirm the export lines exist in `modules/programs/shell.nix`.
3. Open a fresh shell after a home-manager rebuild — exports happen in
   `initContent` which only runs on shell startup.

## Connection Issues

### "ECONNREFUSED" or timeout
**Cause:** Prowlarr not running, wrong port, or off-network.

**Solution:**
1. From the host running Prowlarr: `curl http://localhost:9696/api/v1/system/status`.
2. Verify the LAN IP in `prowlarr_url` is current. Default port is `9696`.
3. Check container logs: `docker logs prowlarr` (or systemd: `journalctl -u prowlarr`).
4. If you configured a URL base, the path becomes `/<urlbase>/api/v1`.
5. Off-network: connect via tailscale or your VPN.

### "SSL certificate problem"
**Cause:** Self-signed or invalid cert when fronting Prowlarr with HTTPS.

**Solution:**
1. Use `-k` for one-off testing: `curl -k https://...`.
2. Add a real cert (Caddy + Let's Encrypt is the easy path).
3. Or fall back to HTTP on the LAN.

## Indexer Issues

### "404 Not Found" when adding indexer
**Cause:** Invalid `implementation` or `implementationName`.

**Solution:**
1. List the available schemas: `GET /api/v1/indexer/schema`.
2. Use exact (case-sensitive) `implementation` and `configContract` from the
   schema entry you want.

### "400 Bad Request" when adding/updating an indexer
**Cause:** Missing required fields or mismatched `configContract`.

**Solution:**
1. Round-trip: fetch the existing indexer with `GET /api/v1/indexer/{id}`,
   mutate, `PUT` the whole object back.
2. For new indexers, start from the schema entry and only fill in the fields
   it declares.

### Indexer added but not returning results
**Cause:** Configuration error, indexer offline, rate limit, or missing
credentials.

**Solution:**
1. Test it: `POST /api/v1/indexer/test` with the full indexer body.
2. Hit the indexer's site in a browser — is it up? Cloudflare-walled?
3. Verify required credentials (API key, cookie, RSS key) are populated in the
   `fields[]` array.
4. Check Prowlarr logs: UI → System → Logs, or
   `docker logs prowlarr | grep -i indexerName`.
5. Some indexers rate-limit hard (1 query / 10s). Slow down test sweeps.

### Indexer test fails
**Cause:** Network connectivity or invalid credentials.

**Solution:**
1. Manually test the indexer URL with curl from the Prowlarr host.
2. Verify VPN / proxy setup if the indexer requires it.
3. Check DNS resolution from the container.
4. Confirm credentials are correct (regenerate API/RSS keys upstream if in
   doubt).

### Indexers not syncing to Sonarr/Radarr
**Cause:** App connection not configured, sync level wrong, or app
unreachable.

**Solution:**
1. Verify apps: `GET /api/v1/applications`.
2. `syncLevel` must be `fullSync` (or at least `addOnly`) for auto-sync.
3. Trigger manually: `POST /api/v1/command` body `{"name": "ApplicationIndexerSync"}`.
4. Test the app connection: `POST /api/v1/applications/test`.
5. Verify the Sonarr/Radarr API key inside Prowlarr's app config matches.

## Search Issues

### "No results" for searches
**Cause:** No indexers enabled, indexers don't support the search type, or
query is too narrow.

**Solution:**
1. List enabled indexers: `GET /api/v1/indexer` and check `enable: true`.
2. Try one indexer at a time with `?indexerIds=N` to isolate failures.
3. Check stats: `GET /api/v1/indexerstats` for failure counts.
4. Broaden the query, or switch search type (e.g. `tvsearch` vs `search`).
5. Confirm the indexer's capabilities include the type you're asking for.

### Slow searches
**Cause:** Multiple indexers timing out.

**Solution:**
1. Disable consistently-failing indexers.
2. Narrow with `indexerIds=` to only the ones you trust.
3. Bump Settings → Indexers → Indexer Timeout if your slow indexers are
   actually viable.

### Missing seeders/peers in results
**Cause:** Some indexers don't report seeder counts.

**Solution:** Normal — sort by another field (size, publishDate) or prefer
indexers that do report.

## Application Sync Issues

### Indexers duplicated in Sonarr/Radarr
**Cause:** Manual indexers in the app plus Prowlarr-synced ones.

**Solution:** Pick one source of truth. The supported path is: remove all
manual indexers from Sonarr/Radarr and let Prowlarr manage everything via
`fullSync`.

### App sync removes indexers I want
**Cause:** Indexer disabled or deleted on the Prowlarr side; `fullSync`
mirrors the removal.

**Solution:**
1. Re-enable in Prowlarr (sync will restore it in apps).
2. Or switch the app's sync level to `addOnly` if you want removals to stay
   manual.

### Wrong categories sync to apps
**Cause:** `syncCategories` field misconfigured on the application entry.

**Solution:**
1. Edit the app: `PUT /api/v1/applications/{id}` with corrected
   `syncCategories` field values.
2. Convention: Movies use 2000-series, TV uses 5000-series, Audio 3000-series,
   Books 7000-series.

## Performance Issues

### High CPU usage
**Cause:** Too many indexers, frequent RSS sync, or one indexer thrashing.

**Solution:**
1. Disable unused indexers.
2. Increase RSS sync interval (Settings → Indexers).
3. Check stats for one indexer with a runaway failure count and disable it.

### Database locked errors
**Cause:** SQLite concurrency saturation.

**Solution:**
1. Backup the DB, restart Prowlarr.
2. Check disk I/O on the volume (`iostat`).
3. Reduce concurrent search load.

## History Issues

### Missing history entries
**Cause:** History retention truncates old rows.

**Solution:** Adjust Settings → General → History Retention. Default keeps
several weeks.

## Known Limitations

- **Search only.** Prowlarr does not download — it hands releases off to
  Sonarr/Radarr/SABnzbd via apps.
- **Rate limits are real.** Respect what each indexer publishes.
- **No bulk search.** One query per API call.
- **Indexer schemas churn.** Indexer definitions update server-side; some
  fields appear/disappear over Prowlarr versions.

## Debug Mode

For verbose logs:

1. Settings → General → Log Level → Debug (or Trace).
2. Restart Prowlarr.
3. Tail logs: `/config/logs/prowlarr.txt` in the container or UI → System →
   Logs.
4. Filter by component (`API`, `IndexerName`).

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| "Indexer already exists" | Duplicate name | Rename or delete the existing one |
| "Unable to connect to indexer" | Network/firewall | Verify connectivity and creds |
| "Invalid API key for application" | Wrong Sonarr/Radarr key | Update inside Prowlarr's app config |
| "Application sync failed" | App unreachable | Test app connection and network |
| "Indexer returned no results" | Query / capability mismatch | Try a different `type` or query |
| "Rate limit exceeded" | Too many requests | Slow down; sleep between queries |
| "Indexer is unavailable" | Upstream down | Temporarily disable the indexer |
| "Invalid search type" | Indexer doesn't support requested `type` | Pick a different indexer or type |
