---
name: add-youtube-channel
description: |
  Subscribe a YouTube channel in TubeArchivist, queue its top videos by views
  from recent uploads, wait for the first file, scan Jellyfin, and rename +
  lock the channel folder to a friendly display name. Use when the user says
  "add a youtube channel", "subscribe to <channel>", or wants a curated
  TubeArchivist + Jellyfin import for a creator.
allowed-tools: Bash
---

# Add YouTube Channel

End-to-end pipeline: TubeArchivist subscribe -> download top-by-views from
recent uploads -> Jellyfin scan -> rename + lock the Jellyfin folder.

## When to invoke

User wants a new creator imported into TubeArchivist and surfaced cleanly in
Jellyfin under a human-readable name (not a `UC...` id).

## Confirm before running

This skill has side effects. **Confirm with the user before running** because
it will:

- Add a new TubeArchivist channel subscription
- Download N videos (storage + bandwidth)
- Rename the channel folder in Jellyfin and lock the `Name` field so future
  metadata refreshes do not overwrite it

Read back the resolved channel name from yt-dlp (run with `--resolve-only`
first if you want a dry-check) before you commit to the full run.

## Environment

Credentials come from sops-nix (see `modules/programs/shell.nix`):

- `TUBEARCHIVIST_URL`, `TUBEARCHIVIST_USERNAME`, `TUBEARCHIVIST_PASSWORD`
- `JELLYFIN_URL`, `JELLYFIN_API_KEY`

The script asserts all five and aborts cleanly otherwise.

## Usage

```bash
bash scripts/add-youtube-channel.sh <handle-or-url> <friendly-name> [--top N] [--recent K]
```

Arguments:

- `<handle-or-url>` — `@example`, `https://www.youtube.com/@example`, or
  `UC...` channel id. Anything yt-dlp accepts.
- `<friendly-name>` — Display name to set in Jellyfin (quote if it has spaces).
- `--top N` — Number of top-viewed videos to queue. Default `20`.
- `--recent K` — Sample size: yt-dlp pulls the most recent K uploads and sorts
  by view count. Default `30`.

Dry-run helpers:

- `--resolve-only` — Only run the yt-dlp handle resolution and print the
  resolved JSON `{channel_id, channel, uploader_id, webpage_url}`. Use this to
  sanity-check a handle (mistyped handles return 404; you'll find out here
  instead of after subscribing).

## Defaults

`--top 20 --recent 30` keeps the initial download light while still favouring
the channel's most popular videos.

## Workflow

1. Resolve handle via yt-dlp (fails fast on typos)
2. POST `/api/channel/` to subscribe in TubeArchivist
3. Pull recent K uploads via yt-dlp `--flat-playlist`, sort by `view_count`,
   take top N
4. POST `/api/download/?autostart=true` with the YouTube IDs
5. POST `/api/task-name/download_pending/` to kick the worker
6. Poll for the first `*.mp4` under `/mnt/media/youtube/<channel_id>/` inside
   the TubeArchivist LXC (`pct exec 120`). 10-minute timeout, 15s poll
7. POST `/Library/Refresh` to trigger a Jellyfin scan
8. Find the new folder under the YouTube library, PATCH `Name` to the friendly
   name, add `"Name"` to `LockedFields`, POST back to `/Items/<id>`

## Transport

yt-dlp runs via `ssh -o BatchMode=yes proxmox 'pct exec 120 -- /opt/tubearchivist/.venv/bin/yt-dlp ...'`
so we use TubeArchivist's bundled binary and don't depend on the workstation
having yt-dlp installed.

## Output

On success, prints a JSON summary to stdout:

```json
{
  "channel_id": "UC...",
  "youtube_name": "Example Channel Name",
  "jellyfin_name": "Example Channel",
  "queued": 20,
  "first_file": "/mnt/media/youtube/UC.../Some-Video [abc].mp4",
  "jellyfin_item_id": "..."
}
```

Progress is logged to stderr with `[HH:MM:SS]` timestamps for each phase.

## Failure modes

- yt-dlp 404 on the handle -> handle is wrong, fix it and rerun
- TubeArchivist login 401 -> sops secret stale; re-source shell
- 10-min timeout waiting for first file -> indexer might be down; check
  `tubearchivist tasks` and `proxmox` LXC 120 logs
- Jellyfin library not found -> the library name must contain "youtube"
  (case-insensitive). Otherwise edit the script's selector.
