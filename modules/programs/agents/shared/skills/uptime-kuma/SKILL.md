---
name: uptime-kuma
description: Manage Uptime Kuma monitors, tags, notifications, maintenance windows, and status pages. Use when the user asks about uptime monitoring, service health, adding monitors, checking status, or managing alerts.
allowed-tools: Bash, AskUserQuestion
---

# Uptime Kuma

Manage the self-hosted Uptime Kuma instance via `kuma-cli` (wrapper around the
`kuma` binary from autokuma). All commands output JSON by default.

## Environment

Variables from sops-nix secrets:
- `KUMA_URL` - Base URL of Uptime Kuma instance
- `KUMA_USERNAME` - Login username
- `KUMA_PASSWORD` - Login password

The `kuma-cli` wrapper passes these automatically as `--url`, `--username`,
`--password` flags.

## CLI Discovery

Run `kuma-cli --help` for top-level commands. Run
`kuma-cli <command> --help` or `kuma-cli <command> <subcommand> --help` for
details.

## Monitors

### List all monitors

```bash
kuma-cli monitor list --pretty
```

Parse with jq for a summary:

```bash
kuma-cli monitor list | jq '.[] | {id, name, type, active, url}'
```

### Get a specific monitor

```bash
kuma-cli monitor get ID --pretty
```

### Add a monitor

Monitors are defined as JSON files. Create a temp file and pass it:

```bash
cat > /tmp/monitor.json <<'EOF'
{
  "type": "http",
  "name": "My Service",
  "url": "https://example.com",
  "interval": 60,
  "maxretries": 3
}
EOF
kuma-cli monitor add /tmp/monitor.json
```

Common monitor types:
- `http` - HTTP(S) endpoint (fields: `url`, `method`, `maxredirects`, `accepted_statuscodes`)
- `ping` - ICMP ping (fields: `hostname`)
- `port` - TCP port check (fields: `hostname`, `port`)
- `keyword` - HTTP + check for keyword (fields: `url`, `keyword`)
- `group` - Group container for other monitors (fields: `name`)
- `docker` - Docker container (fields: `docker_host`, `docker_container`)
- `dns` - DNS record check (fields: `hostname`, `dns_resolve_server`, `dns_resolve_type`)

To add a monitor to a group, set `"parent": GROUP_ID` in the JSON.

When adding a monitor to a group, first list monitors to find group IDs, then
use AskUserQuestion to confirm which group.

### Edit a monitor

Get the current config, modify it, and pass it back:

```bash
kuma-cli monitor get ID > /tmp/monitor.json
# Edit /tmp/monitor.json as needed
kuma-cli monitor edit /tmp/monitor.json
```

### Delete a monitor

```bash
kuma-cli monitor delete ID
```

### Pause / Resume a monitor

```bash
kuma-cli monitor pause ID
kuma-cli monitor resume ID
```

## Tags

### List all tags

```bash
kuma-cli tag list --pretty
```

### Get a specific tag

```bash
kuma-cli tag get ID --pretty
```

### Add a tag

```bash
cat > /tmp/tag.json <<'EOF'
{
  "name": "production",
  "color": "#DC3545"
}
EOF
kuma-cli tag add /tmp/tag.json
```

### Edit / Delete a tag

```bash
kuma-cli tag edit /tmp/tag.json
kuma-cli tag delete ID
```

Tags are assigned to monitors via the monitor's `tags` array in its JSON config.

## Notifications

### List all notifications

```bash
kuma-cli notification list --pretty
```

### Add / Edit / Delete notifications

```bash
kuma-cli notification add /tmp/notification.json
kuma-cli notification edit /tmp/notification.json
kuma-cli notification delete ID
```

## Maintenance Windows

### List all maintenance windows

```bash
kuma-cli maintenance list --pretty
```

### Add a maintenance window

```bash
cat > /tmp/maintenance.json <<'EOF'
{
  "title": "Scheduled maintenance",
  "strategy": "manual",
  "active": true
}
EOF
kuma-cli maintenance add /tmp/maintenance.json
```

### Pause / Resume maintenance

```bash
kuma-cli maintenance pause ID
kuma-cli maintenance resume ID
```

## Status Pages

### List all status pages

```bash
kuma-cli status-page list --pretty
```

### Add / Edit / Get / Delete status pages

```bash
kuma-cli status-page get SLUG --pretty
kuma-cli status-page add /tmp/status-page.json
kuma-cli status-page edit /tmp/status-page.json
kuma-cli status-page delete SLUG
```

## Output Format

- Default output is JSON. Use `--pretty` for human-readable output.
- Use `--format yaml` for YAML output.
- Pipe through `jq` for filtering and formatting.

## Workflow Tips

- When the user asks to add a monitor, ask what type (HTTP, ping, TCP, etc.)
  and the target URL/host before creating the JSON.
- When adding to a group, list existing monitors first to find group IDs and
  confirm with AskUserQuestion.
- For bulk operations, use a loop over monitor IDs.
- Clean up temp files after use.

## Notes

- The CLI uses Socket.IO internally (not REST), connecting directly to Uptime
  Kuma's websocket interface.
- All `add` and `edit` commands accept JSON/YAML file paths as arguments, or
  read from stdin.
- Monitor IDs are integers, status page IDs are slugs (strings).
