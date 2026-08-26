---
name: jellyseerr
description: Browse and moderate media requests in my self-hosted Jellyseerr through Executor. Use for requests, search, media, users, issues, approval, decline, retry, or deletion.
---

# Jellyseerr

Use the `jellyseerr` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `jellyseerr` namespace, describe the selected tool, and call its full address under `jellyseerr.user.jellyseerrHomelab` with `executor_execute`.
3. Branch on Executor's `{ ok, data, error }` result.
4. Resolve request IDs with a read operation before proposing moderation. Resume mutations only after presenting the exact request and action.

Request creation, update/status changes, retries, and deletion are protected by exact-address Executor policies. Deletion is destructive. Do not invoke broader settings, user, media-file, or issue mutation endpoints unless explicitly requested and separately reviewed.
