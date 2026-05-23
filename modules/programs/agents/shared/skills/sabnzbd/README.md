# SABnzbd Skill

Wrapper for the self-hosted SABnzbd HTTP API: inspect the download queue and
history, control the queue, and view server stats from any agent (Claude,
Codex, opencode).

## What's here

```
sabnzbd/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── sabnzbd.sh      # Wrapper exposing sub-commands (status, queue, history, ...)
└── references/
    ├── api-endpoints.md      # API mode reference
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.sabnzbd_url.owner = "michaelvessia";
   secrets.sabnzbd_api_key.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   sabnzbd_url: http://192.168.1.133:7777
   sabnzbd_api_key: <api key from SABnzbd Config -> General -> Security>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/sabnzbd_url" ] && export SABNZBD_URL="$(cat "$SECRETS_DIR/sabnzbd_url")"
   [ -f "$SECRETS_DIR/sabnzbd_api_key" ] && export SABNZBD_API_KEY="$(cat "$SECRETS_DIR/sabnzbd_api_key")"
   ```

## Sub-commands

All commands are run as `bash scripts/sabnzbd.sh <cmd> [args]`.

| Command                              | What it does                                  |
| ------------------------------------ | --------------------------------------------- |
| `status`                             | version, uptime, paused, disk space, warnings |
| `version`                            | SABnzbd version                               |
| `queue`                              | active download queue (slots, speed, ETA)     |
| `history [n]`                        | recent history (default 50)                   |
| `pause`                              | pause the queue                               |
| `resume`                             | resume the queue                              |
| `delete <nzo_id> [--files]`          | remove from queue (optionally delete files)   |
| `server-stats`                       | day/week/month/total bytes per server         |

## Auth model

Unlike Sonarr/Radarr (which use `X-Api-Key` header), SABnzbd authenticates via
the `apikey` query parameter. The wrapper appends
`?apikey=$SABNZBD_API_KEY&output=json&mode=<mode>` to every request.

## Workflows

**Check what's downloading**

```bash
bash scripts/sabnzbd.sh queue
```

**Inspect a stuck or failed item, then remove it**

```bash
bash scripts/sabnzbd.sh queue                       # find the nzo_id
bash scripts/sabnzbd.sh delete SABnzbd_nzo_xxxxx    # keep files
```

**Pause downloads, do something disruptive, resume**

```bash
bash scripts/sabnzbd.sh pause
# ... maintenance ...
bash scripts/sabnzbd.sh resume
```

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- SABnzbd lives on the LAN (`192.168.1.133:7777`). Off-network access requires
  tailscale or VPN.
- The wrapper is intentionally thin: any operation not covered by a
  sub-command (add NZB, speed limit, retry, change category, ...) can be done
  with raw curl against `$SABNZBD_URL/api` using the examples in `references/`.
