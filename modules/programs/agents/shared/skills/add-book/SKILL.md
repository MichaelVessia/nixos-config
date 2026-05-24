---
name: add-book
description: Add an ebook, comic, PDF, or audiobook file to AutoCaliWeb through its ingest folder. Use when the user says "add book", "import ebook", "add to AutoCaliWeb", or provides a book file path/URL to add to the library.
allowed-tools: Bash, WebFetch, AskUserQuestion
---

# Add Book to AutoCaliWeb

Import a user-provided book file by copying it into AutoCaliWeb's watched ingest
folder. AutoCaliWeb then handles import, metadata, cover, conversion, and EPUB
fixing according to its configured automation.

## Environment

- `AUTOCALIWEB_INGEST_DIR` - ingest path inside the AutoCaliWeb LXC, currently `/opt/acw-book-ingest`
- `AUTOCALIWEB_PROXMOX_HOST` - Proxmox SSH host, currently `proxmox`
- `AUTOCALIWEB_CTID` - AutoCaliWeb LXC id, currently `101`
- `AUTOCALIWEB_URL` - UI/OPDS URL for reporting and CLI verification
- `AUTOCALIWEB_USERNAME` - optional, required for the `autocaliweb` CLI
- `AUTOCALIWEB_PASSWORD` - optional, required for the `autocaliweb` CLI

The wrapper uploads through `ssh proxmox` + `pct exec 101` when the Proxmox env
vars are present. Without them, it treats `AUTOCALIWEB_INGEST_DIR` as a local
path.

The installed `autocaliweb` CLI is read-only. Use it for status/search/recent
verification, not for ingesting files. It always emits a single JSON envelope
with `ok`, `command`, `result` or `error`, and `next_actions`.

```bash
autocaliweb status                    # OPDS status + catalog stats
autocaliweb stats                     # database counts
autocaliweb recent --limit 25         # recently added books
autocaliweb search "Book Title"       # search books through OPDS
autocaliweb book-info <uuid>          # Calibre Companion metadata
autocaliweb shelves                   # OPDS shelves
```

## Required Input

The user must provide one of:

- A local readable file path, such as `/home/michaelvessia/Downloads/book.epub`
- A direct `http://` or `https://` file URL they are allowed to download

If the user gives only a title/author, ask for a source file or direct download
URL. Do not search for pirated copies.

## Confirm Before Running

This skill has side effects. Confirm before copying because AutoCaliWeb may
import, convert, modify metadata, and move the file into the Calibre library.

## Usage

```bash
bash scripts/add-book.sh <file-or-url> [--name "Book Title.epub"] [--ingest-dir /path/to/ingest] [--proxmox-host proxmox] [--ctid 101] [--dry-run]
```

Examples:

```bash
bash scripts/add-book.sh ~/Downloads/example.epub
bash scripts/add-book.sh "https://example.com/book.epub" --name "Example.epub"
bash scripts/add-book.sh ~/Downloads/example.pdf --dry-run
```

## Workflow

1. Confirm source path/URL and that the user wants it imported.
2. Run `bash scripts/add-book.sh <source> --dry-run` to validate paths.
3. Run without `--dry-run` to copy/download into `/opt/acw-book-ingest` in LXC 101.
4. Report the destination path and remind the user AutoCaliWeb imports async.
5. If CLI credentials are present, use `autocaliweb recent --limit 10` or
   `autocaliweb search "<title>"` to verify after AutoCaliWeb has had time to
   import the file.
6. If `AUTOCALIWEB_URL` is set, include it for follow-up verification.

## Notes

- The script copies local files. It never moves or deletes the original.
- Existing destination filenames fail instead of overwriting.
- Do not copy directly into `/calibre-library`; Calibre metadata must be updated
  by AutoCaliWeb/Calibre, not a raw filesystem copy.
- Do not claim the book is fully imported unless you verify it in AutoCaliWeb or
  its logs. Copying to ingest only means the import was queued.
- If `autocaliweb` returns an env-missing envelope, fall back to reporting the UI
  URL and queued ingest path instead of claiming verification succeeded.
