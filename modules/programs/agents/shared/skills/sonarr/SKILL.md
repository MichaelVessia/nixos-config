---
name: sonarr
description: Search and manage my self-hosted Sonarr television library through Executor. Use for series, episodes, queue, calendar, missing items, history, status, adding, removing, or searches.
---

# Sonarr

Use the `sonarr` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `sonarr` namespace, describe the selected tool, and call its full address under `sonarr.user.sonarrHomelab` with `executor_execute`.
3. Use lookup/read operations to resolve exact TVDB, series, root-folder, and quality-profile identifiers.
4. Present the complete mutation body and consequences before resuming Executor approval.

Series create/update/delete and command execution are approval gated. For deletion, keep `deleteFiles` false unless the user explicitly confirms permanent episode-file deletion. The former CLI's opinionated add defaults are retired; never invent replacements or assume defaults.
