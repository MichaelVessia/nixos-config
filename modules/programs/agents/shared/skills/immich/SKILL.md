---
name: immich
description: Inspect and search my self-hosted Immich photo/video library. Use when the user asks about Immich, photos, videos, albums, people/faces, recent uploads, library stats, server storage, or background jobs.
allowed-tools: Bash, WebFetch
---

# Immich

Manage my self-hosted Immich (v2.x) photo/video library: inspect server
status and stats, browse users/albums/people/tags, search assets (CLIP-based
smart search + metadata fallback), and check background job queues.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `IMMICH_URL` — base URL, no trailing slash (e.g. `http://192.168.1.82:2283`)
- `IMMICH_API_KEY` — Immich API key

The `immich` CLI reports a JSON error envelope when they are missing.

Immich uses the lowercase header `x-api-key` and exposes the API under `/api/`.
The CLI composes these for you.

## CLI

Use the installed `immich` CLI for common operations. It always emits a single
JSON envelope with `ok`, `command`, `result` or `error`, and `next_actions`.
`scripts/immich.sh` remains as a compatibility shim for older workflows.

```bash
immich status                                # version + ping projected to one object
immich stats                                 # photos, videos, usage, per-user
immich storage                               # disk free space + library size
immich users                                 # users, preferring admin fields when available
immich me                                    # current user attached to the API key
immich albums --limit 25                     # visible albums
immich album-info <id> --limit 25            # full album detail + bounded asset sample
immich search "beach sunset" --limit 25      # smart search, metadata fallback
immich recent --limit 25                     # most recent assets
immich people --limit 25                     # named/unnamed people
immich person-info <id>                      # full person detail
immich jobs                                  # background queues + counts
immich library-stats                         # alias for stats
immich tags                                  # all tags
```

For anything not covered, call the API directly with `$IMMICH_URL` and
`$IMMICH_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: find a photo

1. `immich search "<natural language query>"` — CLIP-based
   semantic search returns matching asset ids.
2. If smart search isn't configured (machine-learning service down), the
   CLI falls back to filename metadata search.
3. Inspect a single asset with `curl -sS -H "x-api-key: $IMMICH_API_KEY" \
   "$IMMICH_URL/api/assets/<id>"` (see quick-reference).

## Workflow: routine status checks

Use `status`, `stats`, `storage`, `jobs` for sanity checks. Drop to raw curl
for niche queries.

## Mutations: confirm first

This skill is read-only by design. There are no asset delete, asset update,
person merge, or album mutation sub-commands in this cut. Any future
mutation sub-commands (e.g. `delete-asset`, `merge-people`,
`album-add-assets`) must:

- Confirm with the user before issuing the request.
- Use the lowest-blast-radius option by default (e.g. trash, not permanent).
- Print what was changed afterwards.

For now, perform mutations from the Immich UI.

## References

- `references/api-endpoints.md` — endpoints used by the CLI, verified
  against Immich v2.5.6
- `references/quick-reference.md` — copy-paste curl recipes
- `references/troubleshooting.md` — auth, permissions (v2 per-permission API
  keys), connection fixes

## Notes

- Immich's API evolves fast. The official docs live at
  https://immich.app/docs/api/ and the OpenAPI spec is published alongside
  each release. Pin docs/spec to the running server version (currently
  `v2.5.6`).
- Immich v2 uses **per-permission API keys**. A key without `asset.read`
  cannot list assets, even though it can hit `/api/server/ping`. 403s here
  almost always mean a missing permission on the key, not a bad URL.
- Header name is **lowercase** `x-api-key`. Other Servarr-style services use
  `X-Api-Key`; do not mix them up.
- Immich runs on the LAN (LXC 117, `http://192.168.1.82:2283`). Off-network
  access needs Tailscale.
