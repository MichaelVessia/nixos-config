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

The wrapper script asserts these are set and aborts cleanly otherwise.

Immich uses the lowercase header `x-api-key` and exposes the API under
`/api/`. The wrapper composes these for you.

## Wrapper script

`scripts/immich.sh` exposes simple sub-commands so the agent doesn't have to
hand-roll curl invocations. All output is JSON.

```bash
bash scripts/immich.sh status                # version + ping projected to one object
bash scripts/immich.sh stats                 # photos, videos, usage, per-user
bash scripts/immich.sh storage               # disk free space + library size
bash scripts/immich.sh users                 # id, name, email, isAdmin, quotaSizeInBytes
bash scripts/immich.sh me                    # current user (whoever the API key belongs to)
bash scripts/immich.sh albums [n]            # first n albums (default 25)
bash scripts/immich.sh album-info <id>       # full album detail
bash scripts/immich.sh search <query>        # CLIP smart search, metadata fallback
bash scripts/immich.sh recent [n]            # most recent assets (default 25)
bash scripts/immich.sh people [n]            # named/unnamed people (default 25)
bash scripts/immich.sh person-info <id>      # full person detail
bash scripts/immich.sh jobs                  # background queues + counts
bash scripts/immich.sh library-stats         # alias for stats
bash scripts/immich.sh tags                  # all tags
bash scripts/immich.sh help                  # usage
```

For anything not covered, call the API directly with `$IMMICH_URL` and
`$IMMICH_API_KEY` — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: find a photo

1. `bash scripts/immich.sh search "<natural language query>"` — CLIP-based
   semantic search returns matching asset ids.
2. If smart search isn't configured (machine-learning service down), the
   wrapper falls back to filename metadata search.
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

- `references/api-endpoints.md` — endpoints used by the wrapper, verified
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
