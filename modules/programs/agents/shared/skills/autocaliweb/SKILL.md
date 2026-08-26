---
name: autocaliweb
description: Browse my self-hosted AutoCaliWeb ebook catalog through Executor and Garage MCP. Use for catalog status, statistics, books, recent additions, search, book metadata, or shelves.
---

# AutoCaliWeb

Use the `garage-mcp` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, read local secret files, or attempt the retired Proxmox/file-ingestion workflow.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Call tools under `garage-mcp.user.garageMcpHomelab` with `executor_execute`.
3. Treat a call as successful only when Executor returns `ok: true` and the MCP result has `isError: false`; read the domain value from `structuredContent`.

## Tools

- `autocaliweb_status`
- `autocaliweb_version`
- `autocaliweb_stats`
- `autocaliweb_catalog`
- `autocaliweb_books` with `{ limit: 1..100 }`
- `autocaliweb_recent` with `{ limit: 1..100 }`
- `autocaliweb_search` with `{ query, limit: 1..100 }`
- `autocaliweb_book_info` with `{ uuid }`
- `autocaliweb_shelves`

All tools are read-only. File upload, URL ingestion, and Proxmox operations are intentionally unsupported. Report Garage MCP's safe structured failure without asking for `AUTOCALIWEB_*` environment variables.
