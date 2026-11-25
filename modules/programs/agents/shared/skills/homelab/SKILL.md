---
name: homelab
description: Find a personal homelab service, its URL, or its health. Route application actions and host checks to the correct service or host.
---

# Homelab

`hearth` (`192.168.1.200`) is the bare-metal NixOS host. Alchemy provisions its Docker apps from `~/projects/homelab-apps`.

| Task | Where to look |
| --- | --- |
| Application API or action | Search the personal Executor for the service and inspect the tool schema. Use a service skill for the workflow. |
| Service placement, ports, or routes | Read `~/nixos-config/modules/homelab/topology.json` for topology and `~/nixos-config/modules/homelab/caddy.nix` for proxy routes. |
| Host, Docker, DNS, networking, or storage | Connect with `ssh root@hearth` and check the live state. |
| Uptime and alerts | Use the [uptime-kuma](../uptime-kuma/SKILL.md) skill. |
| Dashboard entries | Use the [homepage-add](../homepage-add/SKILL.md) skill. |
| Setup history | Read `~/vaults/private/Notes/HOMELAB_SETUP.md`. Confirm current facts against the live system. |

Prefer `https://<service>.home.vessia.net` when Caddy provides a Let's Encrypt route. Use the configured LAN address if there is no HTTPS route. Verify changes through the service or its Executor integration.

Never print credentials or decrypted secret values. Refer to secrets by name.

## Save notes

Save home infrastructure details in the private vault. Read its `AGENTS.md` before you write. After a topology change, update `~/vaults/private/Notes/HOMELAB_SETUP.md`. If the vault is absent, report the pending update. For general lessons or mixed content, follow [obsidian-save](../obsidian-save/SKILL.md). Ask before saving when the destination is ambiguous.
