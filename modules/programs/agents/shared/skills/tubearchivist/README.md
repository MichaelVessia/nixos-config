# TubeArchivist Skill

Wrapper for the self-hosted TubeArchivist (YouTube archiver): subscribe to
channels, inspect indexed content, watch the download queue, and check
Celery worker state from any agent (Claude, Codex, opencode).

## What's here

```
tubearchivist/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── tubearchivist.sh # Wrapper exposing sub-commands (status, channels, ...)
└── references/
    ├── api-endpoints.md      # Endpoint reference + schema fetch
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/CSRF/yt-dlp/connection fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.tubearchivist_url.owner = "michaelvessia";
   secrets.tubearchivist_username.owner = "michaelvessia";
   secrets.tubearchivist_password.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   tubearchivist_url: http://192.168.1.56:8000
   tubearchivist_username: admin
   tubearchivist_password: <password>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/tubearchivist_url" ] && export TUBEARCHIVIST_URL="$(cat "$SECRETS_DIR/tubearchivist_url")"
   [ -f "$SECRETS_DIR/tubearchivist_username" ] && export TUBEARCHIVIST_USERNAME="$(cat "$SECRETS_DIR/tubearchivist_username")"
   [ -f "$SECRETS_DIR/tubearchivist_password" ] && export TUBEARCHIVIST_PASSWORD="$(cat "$SECRETS_DIR/tubearchivist_password")"
   ```

## Sub-commands

All commands are run as `bash scripts/tubearchivist.sh <cmd> [args]`.

| Command                       | What it does                                |
| ----------------------------- | ------------------------------------------- |
| `status`                      | Health + config + stats (video/channel/etc) |
| `channels`                    | List subscribed channels                    |
| `channel-info <channel_id>`   | Detail for one channel                      |
| `subscribe <url-or-id>`       | Subscribe (queues Celery `subscribe_to`)    |
| `unsubscribe <channel_id>`    | Unsubscribe (confirm with user first)       |
| `videos [n]`                  | Recent indexed videos (default 25)          |
| `video-info <youtube_id>`     | Detail for one video                        |
| `downloads`                   | Pending download queue                      |
| `playlists`                   | Indexed playlists                           |
| `tasks`                       | Celery task history (by-name)               |
| `search <query>`              | Cross-index search                          |

## Workflows

**Subscribing**

```bash
bash scripts/tubearchivist.sh subscribe "https://www.youtube.com/@ExampleChannel"
# wait ~30-60s
bash scripts/tubearchivist.sh tasks      # confirm subscribe_to went SUCCESS
bash scripts/tubearchivist.sh channels   # new channel should now appear
```

**Triaging a stalled download** — see
`references/troubleshooting.md#downloads-stuck` and use `tasks` +
`downloads` to inspect Celery and yt-dlp progress.

## Auth notes

TubeArchivist uses Django session + CSRF cookies (not JWT, not API keys).
The wrapper logs in once, caches the cookie jar at
`$TMPDIR/tubearchivist-<uid>/<hash>.jar`, and reuses it for up to 2 days
(TA's session lifetime). Mutating requests (POST/PUT/PATCH/DELETE) attach
`X-CSRFToken` and `Referer` headers automatically.

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- TubeArchivist lives on the LAN (`192.168.1.56:8000`). Off-network access
  requires Tailscale or VPN.
- Downloads land in `/youtube` inside the LXC, which is a symlink to
  `/mnt/media/youtube` (NAS bind mount → `/mnt/synology-media/youtube` on
  the host).
- The wrapper is intentionally thin: anything not covered by a sub-command
  can be done with raw curl against `$TUBEARCHIVIST_URL` using the cookie
  jar — see `references/`.
