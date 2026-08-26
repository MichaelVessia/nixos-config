---
name: immich
description: Inspect my self-hosted Immich library through Executor. Use for server status, storage, users, albums, search, recent assets, people, jobs, or tags.
---

# Immich

Use the `immich` integration through Executor. Do not call a local Garage CLI, use raw curl, request an API key, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `immich` namespace, describe the selected tool, and call its full address under `immich.user.immichHomelab` with `executor_execute`.
3. Branch on Executor's `{ ok, data, error }` result and keep large asset collections bounded.

This skill is read-only. Use discovery operations for status, statistics, storage, users, albums, assets, people, jobs, and tags. Do not invoke create, update, upload, archive, delete, administration, or job-control tools. Report connection failures without asking for `IMMICH_*` environment variables.
