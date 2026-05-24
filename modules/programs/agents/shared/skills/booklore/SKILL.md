---
name: booklore
description: Inspect my self-hosted BookLore library (books, audiobooks, libraries, shelves). Use when the user asks about BookLore, mentions their book/audiobook library, asks what books they have, looks up a title, lists libraries or shelves, or checks the BookLore instance status.
allowed-tools: Bash, WebFetch
---

# BookLore

Read-only CLI for my self-hosted BookLore instance: inspect version, user,
libraries, shelves, and books.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `BOOKLORE_URL` — base URL (no trailing slash), e.g. `http://192.168.1.7:8080`
- `BOOKLORE_USERNAME` — login user
- `BOOKLORE_PASSWORD` — login password

The `booklore` CLI reports a JSON error envelope when they are missing.

## Auth model: JWT, not API key

BookLore has no API-key auth. The flow is:

1. `POST /api/v1/auth/login` with `{"username": "...", "password": "..."}`
2. Response: `{"accessToken": "...", "refreshToken": "...", "isDefaultPassword": false}`
3. Subsequent calls use `Authorization: Bearer <accessToken>`

The CLI logs in when needed, decodes the JWT `exp` claim, and reuses the token
inside the command process.

## CLI

Use the installed `booklore` CLI for common operations. It always emits a
single JSON envelope with `ok`, `command`, `result` or `error`, and
`next_actions`. `scripts/booklore.sh` remains as a compatibility shim for older
workflows.

```bash
booklore status                              # /api/v1/version
booklore version                             # alias for status
booklore me                                  # /api/v1/users/me
booklore libraries                           # /api/v1/libraries
booklore books --limit 50                    # bounded /api/v1/books list
booklore book-info <id>                      # /api/v1/books/<id>
booklore search "Foundation" --limit 25      # client-side title search
booklore shelves                             # /api/v1/shelves
```

For anything not covered, call the API directly with `$BOOKLORE_URL` after
logging in — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: looking up a book

1. `booklore search "<title>"` — client-side filter.
2. `booklore book-info <id>` — full record for the match.

## Workflow: routine status checks

Use `status`, `me`, `libraries`, `shelves` for sanity checks. Drop to raw
curl (after login) for anything else.

## Mutations

This CLI is intentionally read-only. The deployed BookLore version is
`development` and its mutation surface (uploads, edits, deletes) has not
been verified here. Before issuing any POST/PUT/DELETE, confirm with the
user and verify the endpoint exists on the running instance (see the
controller-inspection recipe in `references/troubleshooting.md`).

## References

- `references/api-endpoints.md` — verified endpoints on this deployment,
  plus notes on upstream-main divergence
- `references/quick-reference.md` — copy-paste curl recipes (login, list
  books, refresh token, etc.)
- `references/troubleshooting.md` — auth, connection, 404 (older
  deployment), and how to inspect installed controllers

## Notes

- API is `v1`. Singular paths (`/library`, `/shelf`) and `/healthcheck`
  return 404 — do NOT use those.
- `/api/v1/books` returns a flat array, not a paginated envelope.
- Many endpoints in upstream main (e.g. `/api/v1/auth/refresh`,
  `/api/v1/books/{id}/cover`, downloads) may not exist on this deployed
  instance, which reports `version: "development"`. Verify before relying.
- Access tokens are short-lived; if repeated CLI invocations hit auth errors,
  retry after a second before assuming the credentials are wrong.
- BookLore lives on the LAN (`192.168.1.7:8080`). If `BOOKLORE_URL` is
  unreachable, surface that rather than guessing.
