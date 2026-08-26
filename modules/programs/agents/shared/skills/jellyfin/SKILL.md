---
name: jellyfin
description: Inspect and operate my self-hosted Jellyfin server through Executor. Use for server status, users, libraries, sessions, now playing, recent items, search, counts, or scheduled tasks.
---

# Jellyfin

Use the `jellyfin` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `jellyfin` namespace, describe the selected tool, and call its full address under `jellyfin.user.jellyfinHomelab` with `executor_execute`.
3. Branch on Executor's `{ ok, data, error }` result and keep item queries bounded.
4. Resume approval-gated mutations only after showing the user the exact task and effect.

Scheduled-task mutations are approval gated at:

- `jellyfin.user.jellyfinHomelab.scheduledTasks.startTask`
- `jellyfin.user.jellyfinHomelab.scheduledTasks.stopTask`
- `jellyfin.user.jellyfinHomelab.scheduledTasks.updateTask`

Do not invoke unrelated Jellyfin mutation endpoints merely because the OpenAPI catalog exposes them.
