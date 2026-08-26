---
name: caddy
description: Inspect and manage my self-hosted Caddy reverse proxy through Executor. Use for active configuration, routes, upstreams, PKI, or explicitly requested configuration reloads.
---

# Caddy

Use the `caddy` integration through Executor. Do not call a local Garage CLI, compatibility script, or raw Caddy API.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `caddy` namespace, describe the selected tool, and call its full address under `caddy.user.homelab` with `executor_execute`.
3. Branch on Executor's `{ ok, data, error }` result.
4. If a reload pauses for approval, present the request and use `executor_resume`; never bypass it.

Read the active configuration before proposing a change. Full configuration replacement uses the exact approval-gated address `caddy.user.homelab.load.reloadConfig`. Validate the intended body and explain impact before seeking approval. The former local-file diff workflow is no longer supported.
