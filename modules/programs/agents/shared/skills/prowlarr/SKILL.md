---
name: prowlarr
description: Search and inspect my self-hosted Prowlarr through Executor. Use for status, health, indexers, statistics, release search, applications, history, tests, or explicitly requested synchronization.
---

# Prowlarr

Use the `prowlarr` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `prowlarr` namespace, describe the selected tool, and call its full address under `prowlarr.user.prowlarrHomelab` with `executor_execute`.
3. Branch on Executor's `{ ok, data, error }` result and keep release/history searches bounded.
4. Describe command payloads before invoking them; never guess a command name or application identifier.

Command execution, including application/indexer synchronization, uses the exact approval-gated address `prowlarr.user.prowlarrHomelab.command.postApiV1Command`. Do not mutate indexer or application configuration unless explicitly requested and reviewed.
