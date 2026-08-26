---
name: tubearchivist
description: Browse and operate my self-hosted TubeArchivist archive through Executor. Use for health, channels, videos, downloads, playlists, tasks, search, subscriptions, or queue operations.
---

# TubeArchivist

Use the `tubearchivist` integration through Executor. Do not call a local Garage CLI, use raw curl, request credentials, read local secret files, or run the retired cross-system channel-import/Jellyfin workflow.

## Workflow

1. Load `executor_skills({ name: "execute" })` when needed.
2. Search the `tubearchivist` namespace, describe the selected tool, and call its full address under `tubearchivist.user.tubearchivistHomelab` with `executor_execute`.
3. Use `health.healthRetrieve` for service health; avoid the unrelated endpoint that previously returned an HTML 500 response.
4. Resolve channel/video/task IDs with reads before proposing a mutation. Resume approval only after presenting the exact operation.

Channel subscribe/unsubscribe, download queue changes, and task execution are approval gated at their exact saved-connection addresses. File renaming, remote `yt-dlp`, Jellyfin scanning, and curated creator import are intentionally unsupported.
