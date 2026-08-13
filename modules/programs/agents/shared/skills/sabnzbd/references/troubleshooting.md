# SABnzbd API Troubleshooting

## Authentication Issues

### "API Key Incorrect" / unauthorized response

**Cause:** Wrong or missing API key.

**Solution:**
1. Get the API key from SABnzbd Config -> General -> Security.
2. Update `sabnzbd_api_key` in `secrets/framework13.yaml` via:
   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
     sops set secrets/framework13.yaml '["sabnzbd_api_key"]' '"<new key>"'
   ```
3. Rebuild home-manager (e.g. `home-manager switch`) and open a fresh shell so
   the new value is exported.
4. Verify:
   ```bash
   curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
   ```
5. SABnzbd uses the `apikey` query parameter, not an `X-Api-Key` header.

### "API Key Not Being Sent"

**Cause:** Header-based auth, malformed URL, or the variable being empty.

**Solution:**
1. Confirm both env vars are set in the current shell:
   ```bash
   [ -n "$SABNZBD_URL" ] && [ -n "$SABNZBD_API_KEY" ] && echo ok
   ```
2. If empty, the sops-nix mount may not have populated yet (just-after-boot
   timing). Re-source your shell or wait for `sops-nix.service` to settle.
3. Always pass `?apikey=$SABNZBD_API_KEY&output=json&mode=<mode>`.

## Connection Issues

### Connection Refused / timeout

**Cause:** SABnzbd not running, wrong port, or unreachable from this host.

**Solution:**
1. Confirm SABnzbd is up:
   ```bash
   curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
   ```
2. Verify port (LAN host is `192.168.1.133:7777` per `secrets/framework13.yaml`).
3. Check container/service logs on the host:
   ```bash
   docker logs sabnzbd --tail 100
   ```
4. Test raw connectivity:
   ```bash
   nc -zv 192.168.1.133 7777
   ```

### Host Not Found

**Cause:** DNS or LAN issue.

**Solution:**
1. SABnzbd config uses an IP (`http://192.168.1.133:7777`), so DNS shouldn't
   matter. If it does, you probably overrode `SABNZBD_URL` somewhere.
2. Off-network access needs tailscale or VPN.

## Queue Issues

### Queue Item Stuck "Downloading"

```bash
# Confirm Usenet server is connected
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=fullstatus" \
  | jq '.status.servers[] | {servername, connected, articles_tried, error}'
```

If the server shows errors, restart SABnzbd or pause/resume:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=pause"
sleep 5
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=resume"
```

If still stuck, delete and re-add:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=delete&value=SABnzbd_nzo_abc123"
```

### Queue Paused, won't resume

```bash
# Look for individually paused items (priority -2)
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
  | jq '.queue.slots[] | select(.priority == "-2") | {nzo_id, filename}'

# Resume them by setting priority back to 0
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue&name=priority&value=SABnzbd_nzo_abc123&value2=0"
```

## Category Issues

### Category Not Found

```bash
# Show available categories
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=get_cats" \
  | jq '.categories[]'
```

Category names are case-sensitive. Use the exact value returned above.

## Speed Limit Issues

### Limit Doesn't Apply

```bash
# Verify the current limit
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue" \
  | jq '.queue | {speedlimit, speedlimit_abs, speed}'
```

If `speedlimit_abs` is `0`, no absolute limit is active. Try setting the
absolute value with a suffix:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=5M"
```

### Downloads Too Slow

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=speedlimit&value=0"
```

Check server connection count in `mode=get_config`. SSL/TLS, server slot
limits, and ISP throttling are common culprits.

## NZB Adding Issues

### Can't Add NZB by URL

1. Confirm the URL is reachable from the SABnzbd host:
   ```bash
   curl -I "http://indexer.example/get.php?guid=xyz"
   ```
2. Use `--data-urlencode` so curl encodes special characters:
   ```bash
   curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=addurl" \
     --data-urlencode "name=http://indexer.example/get.php?guid=xyz"
   ```
3. Fall back to uploading the NZB file directly with `mode=addfile`.

### NZB File Upload Fails

```bash
# Sanity-check the file
file /path/to/file.nzb
xmllint --noout /path/to/file.nzb

# Upload (form field name MUST be "nzbfile")
curl -fsS -X POST \
  -F "apikey=$SABNZBD_API_KEY" \
  -F "output=json" \
  -F "mode=addfile" \
  -F "nzbfile=@/path/to/file.nzb" \
  "$SABNZBD_URL/api"
```

## History Issues

### Can't Clear History

If `value=all` doesn't take, delete items individually:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history" \
  | jq -r '.history.slots[].nzo_id' \
  | while read -r nzo_id; do
      curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history&name=delete&value=$nzo_id"
    done
```

### Failed Downloads Don't Appear

```bash
# Inspect raw history slots
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=history" \
  | jq '.history.slots[] | {name, status, fail_message}'
```

Check `auto_disconnect` / cleanup settings in `mode=get_config` — failed items
may have been auto-removed.

## API Response Issues

### Empty / Unexpected JSON

1. Always pass `output=json`; the default is XML.
2. Confirm HTTP status:
   ```bash
   curl -i "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=queue"
   ```
3. The `fullstatus` payload is wrapped under `.status`; the `queue` payload is
   wrapped under `.queue`; the `history` payload is wrapped under `.history`.

### Schema Differences

SABnzbd has changed response shapes across versions. Check the running version
first:

```bash
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
```

## General Debugging

### Verbose curl

```bash
curl -v "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
```

### Stepwise Connectivity Check

```bash
ping -c 3 192.168.1.133
nc -zv 192.168.1.133 7777
curl -I "$SABNZBD_URL"
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=version"
```

### SABnzbd Logs

```bash
docker logs sabnzbd --tail 100

# Or find the log path from the running config
curl -fsS "$SABNZBD_URL/api?apikey=$SABNZBD_API_KEY&output=json&mode=fullstatus" \
  | jq -r '.status.logfile'
```

## Common Error Messages

| Error Message | Cause | Solution |
|--------------|-------|----------|
| `API Key Incorrect` | Wrong/missing API key | Update `sabnzbd_api_key` via sops, rebuild, open fresh shell |
| `Connection refused` | SABnzbd not running | Start the container/service |
| `Invalid NZB` | Malformed/corrupt NZB | Re-fetch the NZB |
| `Category does not exist` | Typo / wrong case | Use a value from `mode=get_cats` |
| `Server not configured` | No Usenet servers in config | Add a server in SABnzbd Config -> Servers |
| `Disk full` | Out of space | Free up disk on download host |
| `Permission denied` | Filesystem perms | Check download dir owner/UID/GID |
| `Timeout` | Network or upstream issue | Retry, check Usenet provider |

## Getting Help

1. Confirm running SABnzbd version: `mode=version`.
2. Official docs: <https://sabnzbd.org/wiki/configuration/4.5/api>.
3. Check SABnzbd logs (see above) for detailed errors.
4. Cross-check via the SABnzbd web UI to rule out API-only issues.
