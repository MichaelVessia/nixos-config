---
name: adguard
description: Inspect and manage my self-hosted AdGuard Home through Executor. Use for DNS status, statistics, query logs, clients, filters, blocking configuration, or protection state.
---

# AdGuard Home

Use the `adguard` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, or read local secret files.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `adguard` namespace, describe the selected tool, then call its full address under `adguard.user.adguardHomelab` with `executor_execute`.
3. Branch on Executor's `{ ok, data, error }` result. Do not infer operation shapes from the former CLI.
4. If Executor pauses a mutation, surface the approval and use `executor_resume`; never bypass policy.

Use read operations directly for status, statistics, query logs, clients, filters, DNS, and DHCP. Global protection changes use the exact approval-gated address `adguard.user.adguardHomelab.global.setProtection`.

Do not perform configuration or protection mutations unless the user requested them. Report Executor connection failures without asking for `ADGUARD_*` environment variables.
