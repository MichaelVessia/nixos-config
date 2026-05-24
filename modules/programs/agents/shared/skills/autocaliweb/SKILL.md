---
name: autocaliweb
description: Inspect my self-hosted AutoCaliWeb library. Use when the user asks about AutoCaliWeb, books in Calibre, OPDS status, recent imports, shelves, catalog stats, or wants to search the ebook library.
allowed-tools: Bash, WebFetch
---

# AutoCaliWeb

Read-only CLI for my self-hosted AutoCaliWeb instance: inspect OPDS status,
catalog stats, books, recent imports, shelves, and individual book metadata.

## Environment

Credentials are exported into the shell by sops-nix and shell defaults:

- `AUTOCALIWEB_URL` - base UI/OPDS URL, defaults to `http://192.168.1.145:8083`
- `AUTOCALIWEB_USERNAME` - login user
- `AUTOCALIWEB_PASSWORD` - login password

The `autocaliweb` CLI reports a JSON error envelope when required env vars are
missing.

## CLI

Use the installed `autocaliweb` CLI for common operations. It always emits a
single JSON envelope with `ok`, `command`, `result` or `error`, and
`next_actions`.

```bash
autocaliweb                         # command tree and configuration health
autocaliweb status                  # OPDS status and catalog stats
autocaliweb version                 # alias for status
autocaliweb stats                   # database counts
autocaliweb catalog                 # top-level OPDS catalog entries
autocaliweb books --limit 50        # bounded alphabetical book list
autocaliweb recent --limit 25       # recently added books
autocaliweb search "Foundation"     # search books through OPDS
autocaliweb book-info <uuid>        # Calibre Companion metadata
autocaliweb shelves                 # OPDS shelves visible to the user
```

## Workflows

For a book lookup:

1. Run `autocaliweb search "<title>" --limit 25`.
2. Run `autocaliweb book-info <uuid>` for the best match.

For import verification:

1. Run `autocaliweb recent --limit 10` after AutoCaliWeb has had time to import.
2. If the title is absent, run `autocaliweb search "<title>" --limit 25`.
3. Do not claim an import completed unless it appears in AutoCaliWeb results.

## Mutations

This skill is read-only. For importing ebook, comic, PDF, or audiobook files,
use the `add-book` skill, which queues files into AutoCaliWeb's ingest folder.

## Notes

- Prefer bounded commands with `--limit` to keep context small.
- If `reachable` is false in the command tree, surface the CLI error instead of
  guessing at server state.
- AutoCaliWeb imports asynchronously; an ingest copy means queued, not fully
  imported.
