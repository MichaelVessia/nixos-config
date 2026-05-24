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

The `sabnzbd` CLI reports a JSON error envelope when they are missing.

## Auth model

SABnzbd authenticates via query string, not header. Every request includes
`?apikey=$SABNZBD_API_KEY&output=json&mode=<mode>`. The CLI handles this.

## CLI

Use the installed `sabnzbd` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/sabnzbd.sh` remains as a compatibility shim for older workflows.

```bash
sabnzbd status                                # version, uptime, paused, disk, warnings
sabnzbd version                               # SABnzbd version
sabnzbd queue --limit 50                      # active download queue
sabnzbd history --limit 50                    # recent history
sabnzbd pause                                 # pause the queue
sabnzbd resume                                # resume the queue
sabnzbd delete <nzo_id>                       # remove from queue, keep files
sabnzbd delete <nzo_id> --files --confirm-delete-files
sabnzbd server-stats                          # day/week/month/total bytes per server
```

For anything not covered (adding NZBs, speed limits, history retry, category
changes), call the API directly with `$SABNZBD_URL` and `$SABNZBD_API_KEY` —
see `references/api-endpoints.md` and `references/quick-reference.md`.

## Workflow: routine status checks

Use the high-level subcommands first (`status`, `queue`, `history`,
`server-stats`). Drop to raw curl for niche operations.

## Mutations: confirm first

Always confirm with the user before:

- `sabnzbd delete <nzo_id> --files --confirm-delete-files` (deletes downloaded files from disk)
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
