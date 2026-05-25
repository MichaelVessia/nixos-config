---
name: homepage-add
description: |
  Add a new service to the Homepage dashboard. Use when a new container or VM
  has been set up on Proxmox and needs to be added to Homepage. Discovers IP
  and port automatically from the container.
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
---

# Homepage Service Entry Manager

Add services running on Proxmox to the Homepage dashboard (LXC 103).

## Arguments

Expects: `<CTID> <service-name>`

Example: `/homepage-add 117 CommaFeed`

If no arguments provided, ask the user for the container ID and service name.

## Discovery Commands

### Get Container IP

```bash
ssh proxmox "pct exec <CTID> -- ip -4 addr show eth0" 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1
```

### Get Listening Ports

```bash
# Find non-system ports (excludes 22, 25, 111, etc)
ssh proxmox "pct exec <CTID> -- ss -tlnp" 2>/dev/null
```

Look for ports that are likely the service (typically 8000-9999 range, or well-known app ports).

### Verify Service is Running

```bash
ssh proxmox "pct exec <CTID> -- systemctl list-units --type=service --state=running" 2>/dev/null | grep -v systemd
```

## Homepage Config Location

Homepage runs on LXC 103. Config file:

```
/opt/homepage/config/services.yaml
```

## Entry Format

Add entries under the appropriate section (Infrastructure, Documents & Books, Utilities, Media).

Basic entry (no widget):
```yaml
    - ServiceName:
        icon: service-name.png
        href: http://<IP>:<PORT>
        description: Short description
        proxmoxNode: pve
        proxmoxType: lxc
        proxmoxVMID: <CTID>
```

## Icon Names

Homepage uses Dashboard Icons. Common patterns:
- Use lowercase with hyphens: `service-name.png`
- Check https://github.com/walkxcode/dashboard-icons for available icons
- Common icons: `jellyfin.png`, `radarr.png`, `sonarr.png`, `adguard-home.png`

## Workflow

1. Get CTID and service name from arguments or ask user
2. Discover IP: `ssh proxmox "pct exec <CTID> -- ip -4 addr show eth0"` and extract IP
3. Discover port: `ssh proxmox "pct exec <CTID> -- ss -tlnp"` and identify service port
4. If multiple non-system ports, ask user which one
5. Read current config: `ssh proxmox "pct exec 103 -- cat /opt/homepage/config/services.yaml"`
6. Ask user which section to add to (Utilities is default for most services)
7. Add the entry to the config (see Card Ordering section for placement)
8. Write back: pipe content to `ssh proxmox "pct exec 103 -- tee /opt/homepage/config/services.yaml > /dev/null"`
9. Verify: `ssh proxmox "pct exec 103 -- grep -A6 <ServiceName> /opt/homepage/config/services.yaml"`
10. Tell user to refresh Homepage

## Existing Sections

From the current config (ordered by card height):
- Infrastructure (Proxmox, Unifi, Synology)
- Documents & Books (Paperless | AutoCaliWeb, LazyLibrarian, Brother) - 2 columns
- Utilities (Syncthing, AdGuard, Caddy, UptimeKuma, Home Assistant, FreshRSS | Tailscale, N8N)
- Media (JellySeerr, Radarr, Sonarr, Prowlarr, SABnzbd, Jellyfin)

The `|` indicates where widget cards end and no-widget cards begin.

## Card Ordering (Minimize Whitespace)

Cards with widgets are taller than cards without. Homepage uses row-based layout, so mixing heights creates whitespace gaps.

**Rule: Group cards by height within each section.**

1. Cards WITH widgets go first (tall cards together)
2. Cards WITHOUT widgets go at the end (short cards together)

Example for Utilities (8 items, 3 columns):
- Row 1: Syncthing, AdGuard, Caddy (all have widgets)
- Row 2: UptimeKuma, Home Assistant, FreshRSS (all have widgets)
- Row 3: Tailscale, N8N (both no widget, same height)

When adding a new service:
- If it has a widget, insert it after the last widget card (before the no-widget cards)
- If it has no widget, append it at the end of the section

## Notes

- Homepage auto-reloads config changes (no restart needed)
- VMs use `proxmoxVMID` without `proxmoxType`
- LXC containers need both `proxmoxVMID` and `proxmoxType: lxc`
