---
name: homelab
description: Discovers and routes homelab service work to the correct live source. Use when a user asks about a self-hosted service, its URL, location, health, or an operation whose access path is unclear.
---

# Homelab Router

Use live discovery before relying on remembered IPs, ports, or topology.

## Route the request

| Need | Start here |
| --- | --- |
| Call an application API or perform an application action | Executor MCP |
| Find where a service runs, inspect processes, logs, ports, storage, or networking | `proxmox` skill |
| Check alerts, uptime, or monitoring coverage | `uptime-kuma` skill |
| Add a service to the dashboard | `homepage-add` skill |
| Find a friendly hostname or reverse-proxy upstream | Caddy config in Proxmox CT 115 |
| Confirm the dashboard's service catalog | Homepage config in Proxmox CT 103 |
| Recover setup history or operational notes | `~/obsidian/Notes/PROXMOX_SETUP.md` |

Use a service-specific skill when one exists.

## Discovery loop

1. Identify the service and whether the user wants discovery, diagnosis, or mutation.
2. Check Executor for a matching integration before inventing a direct API call. Search and describe its tools before invoking one.
3. If placement or connectivity is unclear, discover the guest through Proxmox, then inspect its IP, listeners, service manager, or containers.
4. Use Caddy, Homepage, and Uptime Kuma only for the view each owns: routing, catalog, and monitoring.
5. Consult `PROXMOX_SETUP.md` for context that live systems cannot reveal; verify stale facts against the live system.

Discovery is complete only when the service identity, runtime location, user-facing URL, health signal, and intended access mechanism are known or explicitly marked unavailable.

## Operating rules

- Prefer Executor for supported application operations; do not bypass its policies or approval pauses.
- Keep discovery read-only until the user authorizes a mutation.
- Never print credentials or decrypted secret values. Refer to secret and environment variable names only.
- Verify a mutation through the owning service or Executor, not only through command exit status.
- After topology changes, update `~/obsidian/Notes/PROXMOX_SETUP.md`; add or update Homepage and Uptime Kuma only when the change requires them.
