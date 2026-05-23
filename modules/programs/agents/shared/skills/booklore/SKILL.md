---
name: booklore
description: Inspect my self-hosted BookLore library (books, audiobooks, libraries, shelves). Use when the user asks about BookLore, mentions their book/audiobook library, asks what books they have, looks up a title, lists libraries or shelves, or checks the BookLore instance status.
allowed-tools: Bash, WebFetch
---

# BookLore

Read-only wrapper for my self-hosted BookLore instance: inspect version, user,
libraries, shelves, and books.

## Environment

Credentials are exported into the shell by sops-nix (see
`modules/programs/shell.nix`):

- `BOOKLORE_URL` — base URL (no trailing slash), e.g. `http://192.168.1.7:8080`
- `BOOKLORE_USERNAME` — login user
- `BOOKLORE_PASSWORD` — login password

The wrapper script asserts all three are set and aborts cleanly otherwise.

## Auth model: JWT, not API key

BookLore has no API-key auth. The flow is:

1. `POST /api/v1/auth/login` with `{"username": "...", "password": "..."}`
2. Response: `{"accessToken": "...", "refreshToken": "...", "isDefaultPassword": false}`
3. Subsequent calls use `Authorization: Bearer <accessToken>`

`scripts/booklore.sh` caches the access token in a per-user/per-URL
tempfile (`$TMPDIR/booklore-<uid>/<hash>.token`) and decodes the JWT's
`exp` claim to decide whether to reuse or re-login. The `login` helper
inside the script returns a valid token on stdout; every other
sub-command calls it once at the top.

This is also a workaround for a server-side bug in the deployed
`development` build: two logins in the same wall-clock second produce
identical refresh tokens and trip a UNIQUE constraint on
`refresh_token`, returning HTTP 400. The cache means we log in roughly
once per JWT lifetime instead of once per call.

## Wrapper script

`scripts/booklore.sh` exposes simple sub-commands. All output is JSON or
pre-formatted text.

```bash
bash scripts/booklore.sh status              # /api/v1/version
bash scripts/booklore.sh version             # alias for status
bash scripts/booklore.sh me                  # /api/v1/users/me
bash scripts/booklore.sh libraries           # /api/v1/libraries
bash scripts/booklore.sh books [n]           # /api/v1/books (default 50)
bash scripts/booklore.sh book-info <id>      # /api/v1/books/<id>
bash scripts/booklore.sh search <query>      # client-side title filter on /api/v1/books
bash scripts/booklore.sh shelves             # /api/v1/shelves
bash scripts/booklore.sh help
```

For anything not covered, call the API directly with `$BOOKLORE_URL` after
logging in — see `references/api-endpoints.md` and
`references/quick-reference.md`.

## Workflow: looking up a book

1. `bash scripts/booklore.sh search "<title>"` — client-side filter.
2. `bash scripts/booklore.sh book-info <id>` — full record for the match.

## Workflow: routine status checks

Use `status`, `me`, `libraries`, `shelves` for sanity checks. Drop to raw
curl (after login) for anything else.

## Mutations

This wrapper is intentionally read-only. The deployed BookLore version is
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
- Access tokens are short-lived; the script caches them in a tempfile
  with a 30s safety margin against `exp` and re-logins automatically.
- Two logins in the same second hit a UNIQUE-constraint bug on this
  build's `refresh_token` table; the token cache avoids it.
- BookLore lives on the LAN (`192.168.1.7:8080`). If `BOOKLORE_URL` is
  unreachable, surface that rather than guessing.
