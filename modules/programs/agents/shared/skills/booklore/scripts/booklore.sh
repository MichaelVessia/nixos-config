#!/usr/bin/env bash
# BookLore API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
#
# Auth: BookLore uses JWT. The wrapper caches the access token in a
# per-user/per-URL tempfile and reuses it until the JWT's exp passes.
# This both saves an HTTP roundtrip and works around a server bug in
# this development build: two logins inside the same wall-clock second
# produce identical refresh tokens, which violates a UNIQUE constraint
# on refresh_token and returns HTTP 400.
set -euo pipefail

: "${BOOKLORE_URL:?BOOKLORE_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${BOOKLORE_USERNAME:?BOOKLORE_USERNAME not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${BOOKLORE_PASSWORD:?BOOKLORE_PASSWORD not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${BOOKLORE_URL%/}/api/v1"

# Token cache: keyed by URL+username, scoped to current uid.
cache_key=$(printf '%s\n%s' "$BOOKLORE_URL" "$BOOKLORE_USERNAME" \
  | sha256sum | awk '{print $1}')
CACHE_DIR="${TMPDIR:-/tmp}/booklore-$(id -u)"
CACHE_FILE="$CACHE_DIR/${cache_key}.token"

# Decode a JWT's exp claim (seconds since epoch). Empty on failure.
jwt_exp() {
  local jwt="$1" payload pad decoded
  payload="${jwt#*.}"
  payload="${payload%.*}"
  # base64url -> base64
  payload="${payload//-/+}"
  payload="${payload//_//}"
  pad=$(( (4 - ${#payload} % 4) % 4 ))
  while [ "$pad" -gt 0 ]; do payload="${payload}="; pad=$((pad - 1)); done
  decoded=$(printf '%s' "$payload" | base64 -d 2>/dev/null || true)
  printf '%s' "$decoded" | jq -r '.exp // empty' 2>/dev/null || true
}

# Log in and write a fresh token to the cache. Echoes the access token.
do_login() {
  local body resp token
  body=$(jq -n --arg u "$BOOKLORE_USERNAME" --arg p "$BOOKLORE_PASSWORD" \
    '{username:$u, password:$p}')
  resp=$(curl -fsS -X POST -H "Content-Type: application/json" \
    -d "$body" "$API/auth/login")
  token=$(echo "$resp" | jq -r '.accessToken // empty')
  if [ -z "$token" ]; then
    echo "ERROR: login returned no accessToken" >&2
    echo "$resp" >&2
    exit 1
  fi
  mkdir -p "$CACHE_DIR"
  chmod 700 "$CACHE_DIR"
  ( umask 077; printf '%s' "$token" > "$CACHE_FILE" )
  printf '%s' "$token"
}

# Return a valid access token, reusing the cached one when possible.
login() {
  if [ -f "$CACHE_FILE" ]; then
    local cached exp now
    cached=$(cat "$CACHE_FILE" 2>/dev/null || true)
    if [ -n "$cached" ]; then
      exp=$(jwt_exp "$cached")
      now=$(date +%s)
      # 30s safety margin
      if [ -n "$exp" ] && [ "$now" -lt "$((exp - 30))" ]; then
        printf '%s' "$cached"
        return 0
      fi
    fi
  fi
  do_login
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  status|version)
    TOKEN=$(login)
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/version" | jq
    ;;

  me)
    TOKEN=$(login)
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/users/me" \
      | jq '{id, username, email, permissions: (.permissions // null)}'
    ;;

  libraries)
    TOKEN=$(login)
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/libraries" \
      | jq '[.[] | {id, name, paths: (.paths // [])}]'
    ;;

  books)
    n="${1:-50}"
    TOKEN=$(login)
    # On this deployment, top-level title/authors are often null and the real
    # values live under .metadata. Surface both so callers can fall back.
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/books" \
      | jq --argjson n "$n" '
          [.[] | {
            id,
            title: (.title // .metadata.title // null),
            authors: (.authors // .metadata.authors // null),
            libraryId,
            metadata: (.metadata // null)
          }] | .[:$n]'
    ;;

  book-info)
    id="${1:?usage: book-info <id>}"
    TOKEN=$(login)
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/books/$id" | jq
    ;;

  search)
    query="${1:?usage: search <query>}"
    TOKEN=$(login)
    # Client-side filter: this older deployment may not expose server-side
    # search. Fetch all books and grep titles case-insensitively, checking
    # both the top-level title and metadata.title (top-level is often null).
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/books" \
      | jq --arg q "$query" '
          [.[]
            | select(((.title // .metadata.title // "")) | test($q; "i"))
            | {
                id,
                title: (.title // .metadata.title // null),
                authors: (.authors // .metadata.authors // null),
                libraryId
              }]'
    ;;

  shelves)
    TOKEN=$(login)
    curl -fsS -H "Authorization: Bearer $TOKEN" "$API/shelves" | jq
    ;;

  help|--help|-h|"")
    cat <<EOF
booklore.sh — wrapper for BookLore v1 API (JWT login per call)

env required: BOOKLORE_URL, BOOKLORE_USERNAME, BOOKLORE_PASSWORD (from sops-nix)

commands:
  status | version          GET /api/v1/version
  me                        GET /api/v1/users/me
  libraries                 GET /api/v1/libraries
  books [n]                 GET /api/v1/books (project first n, default 50)
  book-info <id>            GET /api/v1/books/<id>
  search <query>            client-side title filter on /api/v1/books
  shelves                   GET /api/v1/shelves
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
