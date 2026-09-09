---
name: home-assistant-manager
description: Configure, diagnose, or deploy the personal Home Assistant instance, including automations and Lovelace dashboards.
---

# Home Assistant Manager

Use the local configuration repository and the `homeassistant` SSH alias.

- REST operations use `hass-cli` with `HASS_SERVER` and `HASS_TOKEN`.
- HA OS commands require a login shell to load `SUPERVISOR_TOKEN`:
  `ssh homeassistant "bash -l -c 'ha core check'"`.
- Check only the credentials and tools needed for the selected operation.

## Select the relevant reference

- Configuration deployment, reload decisions, automation checks, or logs:
  [operations.md](references/operations.md).
- Lovelace registration, layout, cards, templates, or tablet display:
  [dashboards.md](references/dashboards.md).

Command sequences are examples. Apply only steps covered by the user's request.
For an authorized deployment, check the deployed configuration before reload or
restart, then verify the affected behavior. Trigger automations only when their
device or notification effects are within the authorized scope. Prefer state,
trace, or log inspection otherwise.

Complete requested local changes and relevant checks. For deployment tasks,
continue through deployment and verification, correcting failures caused by the
change. Stop when verification passes or further work requires new authority or
missing credentials. Do not infer commit or push authority from a configuration
edit request.
