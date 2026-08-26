---
name: radarr
description: Search and manage my self-hosted Radarr movie library through Executor. Use for movies, collections, queue, calendar, missing items, history, status, adding, removing, or searches.
---

# Radarr

Use the `radarr` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `radarr` namespace, describe the selected tool, and call its full address under `radarr.user.radarrHomelab` with `executor_execute`.
3. Use lookup/read operations to resolve exact TMDB, movie, root-folder, and quality-profile identifiers.
4. Present the complete mutation body and consequences before resuming Executor approval.

Movie create/update/delete and command execution are approval gated. For deletion, keep `deleteFiles` false unless the user explicitly confirms permanent media-file deletion. The former CLI's opinionated defaults and collection workflows are retired; never invent replacements or assume defaults.
