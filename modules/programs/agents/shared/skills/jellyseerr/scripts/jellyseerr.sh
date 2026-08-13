#!/usr/bin/env bash
# Jellyseerr API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${JELLYSEERR_URL:?JELLYSEERR_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${JELLYSEERR_API_KEY:?JELLYSEERR_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${JELLYSEERR_URL%/}/api/v1"
AUTH="X-Api-Key: $JELLYSEERR_API_KEY"

cmd="${1:-help}"
shift || true

urlencode() { jq -sRr @uri <<<"$1"; }

case "$cmd" in
  status)
    curl -fsS -H "$AUTH" "$API/status" | jq '{version, commitTag, updateAvailable, commitsBehind, restartRequired}'
    ;;

  requests)
    # default: pending only. --all returns every state.
    filter="pending"
    if [ "${1:-}" = "--all" ]; then
      filter="all"
    fi
    curl -fsS -H "$AUTH" "$API/request?take=50&sort=added&filter=${filter}" | jq '
      .results[] | {
        id,
        status,
        type,
        createdAt,
        updatedAt,
        requestedBy: (.requestedBy.displayName // .requestedBy.username // null),
        mediaId: .media.id,
        tmdbId: .media.tmdbId,
        mediaType: .media.mediaType,
        mediaStatus: .media.status
      }'
    ;;

  request-counts)
    curl -fsS -H "$AUTH" "$API/request/count" | jq
    ;;

  search)
    query="${1:?usage: search <query>}"
    curl -fsS -H "$AUTH" "$API/search?query=$(urlencode "$query")" | jq -r '
      .results | to_entries | .[:10] | .[] |
      "\(.key + 1). [\(.value.mediaType)] \((.value.title // .value.name // "?")) (\((.value.releaseDate // .value.firstAirDate // "?")[0:4])) [tmdb:\(.value.id)]"
    '
    ;;

  media-status)
    mediaId="${1:?usage: media-status <mediaId>}"
    curl -fsS -H "$AUTH" "$API/media/${mediaId}" | jq
    ;;

  recently-added)
    curl -fsS -H "$AUTH" "$API/media?filter=available&sort=mediaAdded&take=50" | jq '
      .results[] | {id, mediaType, tmdbId, status, mediaAdded, title: (.title // .name)}'
    ;;

  approve)
    requestId="${1:?usage: approve <requestId>}"
    curl -fsS -X POST -H "$AUTH" "$API/request/${requestId}/approve" | jq '{id, status, type, mediaId: .media.id, tmdbId: .media.tmdbId}'
    ;;

  decline)
    requestId="${1:?usage: decline <requestId>}"
    curl -fsS -X POST -H "$AUTH" "$API/request/${requestId}/decline" | jq '{id, status, type, mediaId: .media.id, tmdbId: .media.tmdbId}'
    ;;

  delete-request)
    requestId="${1:?usage: delete-request <requestId>}"
    curl -fsS -X DELETE -H "$AUTH" "$API/request/${requestId}" -o /dev/null -w "%{http_code}\n"
    ;;

  users)
    curl -fsS -H "$AUTH" "$API/user?take=100" | jq '.results[] | {id, email, displayName, username: (.jellyfinUsername // .plexUsername // .username), userType, permissions}'
    ;;

  issues)
    curl -fsS -H "$AUTH" "$API/issue?take=50&filter=open" | jq '
      .results[] | {
        id,
        issueType,
        status,
        createdAt,
        createdBy: (.createdBy.displayName // .createdBy.username // null),
        mediaId: .media.id,
        tmdbId: .media.tmdbId,
        mediaType: .media.mediaType
      }'
    ;;

  help|--help|-h|"")
    cat <<EOF
jellyseerr.sh — wrapper for Jellyseerr v1 API (Overseerr-compatible)

env required: JELLYSEERR_URL, JELLYSEERR_API_KEY (from sops-nix)

commands:
  status                           GET /status
  requests [--all]                 pending requests (default) or all
  request-counts                   GET /request/count
  search <query>                   TMDB multi-search (movies + TV)
  media-status <mediaId>           GET /media/<id>
  recently-added                   available media, sorted by mediaAdded
  approve <requestId>              POST /request/<id>/approve  (confirm first)
  decline <requestId>              POST /request/<id>/decline  (confirm first)
  delete-request <requestId>       DELETE /request/<id>        (confirm first)
  users                            GET /user  (admin only)
  issues                           GET /issue (open issues)
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
