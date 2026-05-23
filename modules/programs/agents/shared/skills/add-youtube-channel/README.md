# add-youtube-channel

End-to-end pipeline that takes a YouTube handle and a friendly display name,
then:

1. Resolves the handle via yt-dlp (fails fast on typos)
2. Subscribes in TubeArchivist (`POST /api/channel/`)
3. Picks the top-N by view count from the most recent K uploads
4. Queues them with autostart (`POST /api/download/?autostart=true`)
5. Triggers the `download_pending` task
6. Waits for the first `*.mp4` to appear on disk in the TubeArchivist LXC
7. Triggers a Jellyfin library scan
8. Renames the new channel folder in Jellyfin and locks the `Name` field

The defaults (`--top 20 --recent 30`) keep the initial download light while
still favouring the channel's most popular videos.

## Layout

```
add-youtube-channel/
├── SKILL.md
├── README.md
└── scripts/
    └── add-youtube-channel.sh
```

## Setup

Credentials come from sops-nix, not a `.env` file. The five env vars below are
exported by `modules/programs/shell.nix`:

- `TUBEARCHIVIST_URL`
- `TUBEARCHIVIST_USERNAME`
- `TUBEARCHIVIST_PASSWORD`
- `JELLYFIN_URL`
- `JELLYFIN_API_KEY`

Open a fresh shell after a `home-manager switch` so the secrets are sourced.

## Usage

```bash
# Full run
bash scripts/add-youtube-channel.sh @ExampleChannel "Example Channel"

# Tune the recipe
bash scripts/add-youtube-channel.sh @ExampleChannel "Example Channel" --top 15 --recent 50

# Dry-check the handle (only runs yt-dlp resolution)
bash scripts/add-youtube-channel.sh @ExampleChannel --resolve-only
```

## Transport

yt-dlp runs remotely via:

```
ssh -o BatchMode=yes proxmox 'pct exec 120 -- /opt/tubearchivist/.venv/bin/yt-dlp ...'
```

This reuses TubeArchivist's bundled yt-dlp and cookies, and means the
workstation doesn't need yt-dlp installed.

## Confirm-before-act

Has real side effects (subscription, downloads, Jellyfin metadata change with
a `LockedFields` write). Always confirm with the user before running.

## Failure modes

- yt-dlp 404 on the handle: handle is wrong or doesn't exist. Use
  `--resolve-only` to confirm the canonical handle before subscribing.
- TubeArchivist login 401: re-source the shell to refresh sops secrets.
- 10-minute wait timeout for first download: check `tubearchivist tasks` and
  the LXC 120 logs on Proxmox.
- Jellyfin library not found: selector matches libraries whose Name contains
  "youtube" (case-insensitive). Rename or adjust the selector if needed.
