---
name: sabnzbd
description: Inspect and control my self-hosted SABnzbd Usenet downloader. Use when the user asks about SABnzbd, NZB downloads, the Usenet queue, download history, server stats, or asks to pause/resume/delete a download.
allowed-tools: Bash, WebFetch
---

# SABnzbd

Manage my self-hosted SABnzbd (HTTP API, v4.5+): check the download queue and
history, pause/resume the queue, delete queue items, and view server stats.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `SABNZBD_URL` — base URL (no trailing slash)
- `SABNZBD_API_KEY` — API key from SABnzbd Config -> General -> Security

The wrapper script asserts these are set and aborts cleanly otherwise.

## Auth model

SABnzbd authenticates via query string, not header. Every request includes
`?apikey=$SABNZBD_API_KEY&output=json&mode=<mode>`. The script handles this.

## Wrapper script

`scripts/sabnzbd.sh` exposes simple sub-commands so the agent doesn't have to
hand-roll curl invocations for common operations.

```bash
bash scripts/sabnzbd.sh status                # version, uptime, paused, disk, warnings
bash scripts/sabnzbd.sh version               # SABnzbd version
bash scripts/sabnzbd.sh queue                 # active download queue
bash scripts/sabnzbd.sh history [n]           # recent history (default 50)
bash scripts/sabnzbd.sh pause                 # pause the queue
bash scripts/sabnzbd.sh resume                # resume the queue
bash scripts/sabnzbd.sh delete <nzo_id>       # remove from queue, keep files
bash scripts/sabnzbd.sh delete <nzo_id> --files  # delete files too (confirm first!)
bash scripts/sabnzbd.sh server-stats          # day/week/month/total bytes per server
```

For anything not covered (adding NZBs, speed limits, history retry, category
changes), call the API directly with `$SABNZBD_URL` and `$SABNZBD_API_KEY` —
see `references/api-endpoints.md` and `references/quick-reference.md`.

## Workflow: routine status checks

Use the high-level subcommands first (`status`, `queue`, `history`,
`server-stats`). Drop to raw curl for niche operations.

## Mutations: confirm first

Always confirm with the user before:

- `delete <nzo_id> --files` (deletes downloaded files from disk)
- `purge` style operations (`mode=queue&name=delete&value=all`)
- Clearing history (`mode=history&name=delete&value=all`)
- Speed-limit changes that affect ongoing downloads
- Any custom POST against `/api` that mutates state

## References

- `references/api-endpoints.md` — full API mode reference with
  request/response shapes
- `references/quick-reference.md` — copy-paste curl recipes for common ops
- `references/troubleshooting.md` — auth, connection, and common error fixes

## Notes

- API style is `?mode=<mode>` against a single `/api` endpoint, not REST.
- `output=json` is required for JSON responses; default is XML.
- SABnzbd lives on the LAN. If `$SABNZBD_URL` is unreachable, surface that to
  the user rather than guessing.
- NZO IDs look like `SABnzbd_nzo_xxxxxxxx` and identify both queue and history
  items.
