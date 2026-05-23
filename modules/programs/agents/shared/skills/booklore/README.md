# BookLore Skill

Wrapper for the self-hosted BookLore instance: inspect the version, the
logged-in user, libraries, shelves, and books from any agent (Claude, Codex,
opencode).

## What's here

```
booklore/
├── SKILL.md            # Skill manifest (frontmatter + workflow guidance)
├── README.md           # This file
├── scripts/
│   └── booklore.sh     # Wrapper exposing sub-commands (status, books, …)
└── references/
    ├── api-endpoints.md      # Verified v1 endpoints on this deployment
    ├── quick-reference.md    # Copy-paste recipes
    └── troubleshooting.md    # Auth/connection/error fixes
```

## Setup

Credentials come from sops-nix, not a `.env` file. BookLore has no API key,
so we store the login username/password and let the wrapper script do a JWT
login on each invocation.

1. Declared as secrets in `modules/secrets/default.nix`:
   ```nix
   secrets.booklore_url.owner = "michaelvessia";
   secrets.booklore_username.owner = "michaelvessia";
   secrets.booklore_password.owner = "michaelvessia";
   ```
2. Stored in `secrets/framework13.yaml` (sops-encrypted):
   ```yaml
   booklore_url: http://192.168.1.7:8080
   booklore_username: <user>
   booklore_password: <pass>
   ```
3. Exported into the shell by `modules/programs/shell.nix`:
   ```sh
   [ -f "$SECRETS_DIR/booklore_url" ] && export BOOKLORE_URL="$(cat "$SECRETS_DIR/booklore_url")"
   [ -f "$SECRETS_DIR/booklore_username" ] && export BOOKLORE_USERNAME="$(cat "$SECRETS_DIR/booklore_username")"
   [ -f "$SECRETS_DIR/booklore_password" ] && export BOOKLORE_PASSWORD="$(cat "$SECRETS_DIR/booklore_password")"
   ```

## Sub-commands

All commands are run as `bash scripts/booklore.sh <cmd> [args]`.

| Command              | What it does                                          |
| -------------------- | ----------------------------------------------------- |
| `status` / `version` | `GET /api/v1/version` — sanity check                  |
| `me`                 | `GET /api/v1/users/me` (id, username, email, perms)   |
| `libraries`          | `GET /api/v1/libraries` (id, name, paths)             |
| `books [n]`          | `GET /api/v1/books`, project first n entries (def 50) |
| `book-info <id>`     | `GET /api/v1/books/<id>` — full object                |
| `search <query>`     | Client-side title filter against `/api/v1/books`      |
| `shelves`            | `GET /api/v1/shelves`                                 |

## Workflows

**Looking up a book**

```bash
bash scripts/booklore.sh search "Project Hail Mary"
bash scripts/booklore.sh book-info 142
```

**Sanity check**

```bash
bash scripts/booklore.sh status
bash scripts/booklore.sh me
bash scripts/booklore.sh libraries
```

## Notes

- Requires `curl` and `jq` (both already in your dev shell).
- BookLore lives on the LAN (`192.168.1.7:8080`). Off-network access requires
  Tailscale or VPN.
- Auth is JWT (no API key). The wrapper caches the access token in
  `$TMPDIR/booklore-<uid>/` keyed by URL+username, decodes the JWT `exp`
  claim, and re-logins automatically when needed. This also dodges a
  server bug in this build that rejects two logins in the same second.
- The deployed instance reports `version: "development"`; some endpoints
  shown in upstream main (refresh, covers, downloads) may not exist here.
  See `references/api-endpoints.md` and the controller-inspection recipe in
  `references/troubleshooting.md`.
- The wrapper is read-only by design. Any POST/PUT/DELETE work should be
  hand-rolled with raw curl after `login`, and confirmed with the user.
