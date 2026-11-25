---
name: home-assistant-manager
description: Configure, diagnose, or deploy the personal Home Assistant instance, including automations and Lovelace dashboards.
---

# Home Assistant

Home Assistant OS runs in the `homelab-homeassistant` VM on `hearth`. Use `ssh root@hearth` for VM checks and `ssh homeassistant` for guest configuration and HA OS commands. Use `https://homeassistant.home.vessia.net` for the UI.

- Search the personal Executor for Home Assistant and use it for supported application actions. For other REST operations, use `hass-cli` with `HASS_SERVER` and `HASS_TOKEN`.
- Use the local configuration repository for edits. For Git deployment, HA OS commands, reload decisions, and verification, follow [operations](references/operations.md).
- For local Lovelace files, dashboard registration, layout, and tablet display, follow [dashboards](references/dashboards.md).

For an authorized deployment, check the deployed configuration before reload or restart. Then verify the affected behavior. Trigger automations only when their device or notification effects are within the authorized scope. Otherwise inspect state, traces, or logs.
