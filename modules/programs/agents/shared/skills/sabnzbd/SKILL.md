---
name: sabnzbd
description: Inspect and control my self-hosted SABnzbd Usenet downloader through Executor and Garage MCP. Use when the user asks about SABnzbd, NZB downloads, the Usenet queue, download history, server stats, or asks to pause, resume, or delete a queued download.
---

# SABnzbd

Use the `garage-mcp` integration through the Executor MCP server. Do not call a
local `sabnzbd` binary, use raw curl, request an API key, or expose service
credentials. Executor owns the connection and approval policy; Garage MCP owns
the domain-shaped SABnzbd tools.

## Executor workflow

1. Load Executor's execution guidance with `executor_skills({ name: "execute" })`
   when it is not already available.
2. Use `executor_execute` to call tools under this connection:
   `garage-mcp.user.garageMcpHomelab`.
3. Treat an operation as successful only when Executor returns `ok: true` and
   the MCP tool result has `isError: false`. Read the domain value from
   `structuredContent`.
4. If Executor pauses a mutation for approval, surface the approval request and
   resume through `executor_resume`. Never bypass or replace the policy.

Example Executor sandbox call:

```ts
const result = await tools[
  "garage-mcp.user.garageMcpHomelab.sabnzbd_queue"
]({ limit: 50 })
return result
```

## Available tools

| Tool | Input | Purpose |
| --- | --- | --- |
| `sabnzbd_status` | `{}` | Version, uptime, pause state, storage, speed limits, and warnings |
| `sabnzbd_version` | `{}` | Running SABnzbd version |
| `sabnzbd_queue` | `{ limit: 1..100 }` | Bounded active queue and totals |
| `sabnzbd_history` | `{ limit: 1..100 }` | Bounded recent history and totals |
| `sabnzbd_server_stats` | `{}` | Day/week/month/total usage by news server |
| `sabnzbd_pause` | `{}` | Pause the global queue; Executor approval required |
| `sabnzbd_resume` | `{}` | Resume the global queue; Executor approval required |
| `sabnzbd_delete` | `{ nzoId, deleteFiles, confirmDeleteFiles }` | Delete one queue item; Executor approval required |

NZO IDs look like `SABnzbd_nzo_xxxxxxxx`. Obtain the exact ID from
`sabnzbd_queue`; never infer one from a display name.

Executor policies must match these exact saved-connection addresses:

- `garage-mcp.user.garageMcpHomelab.sabnzbd_pause`
- `garage-mcp.user.garageMcpHomelab.sabnzbd_resume`
- `garage-mcp.user.garageMcpHomelab.sabnzbd_delete`

All three policies were exercised through Executor and cancelled before tool
invocation during migration verification.

## Safety

- Read tools may run directly.
- Pause and resume must pass Executor's approval policy.
- Every delete must pass Executor's destructive-operation approval policy.
- Before setting `deleteFiles: true`, explicitly confirm with the user that the
  downloaded data should be removed from disk. Then set both `deleteFiles: true`
  and `confirmDeleteFiles: true`; Garage MCP rejects the operation otherwise.
- Do not execute a fake or real destructive operation merely to test policy.
- Do not fall back to raw SABnzbd API calls for unsupported operations. Explain
  that the operation is not exposed and propose adding a reviewed Garage MCP
  tool.

## Failure handling

Report Garage MCP's safe error code, message, and remediation. For connection or
configuration failures, identify the failing Executor/Garage MCP integration;
do not ask the user to export `SABNZBD_URL` or `SABNZBD_API_KEY` locally.
