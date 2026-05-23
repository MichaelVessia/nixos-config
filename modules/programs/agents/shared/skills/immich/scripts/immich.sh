#!/usr/bin/env bash
# Immich API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${IMMICH_URL:?IMMICH_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${IMMICH_API_KEY:?IMMICH_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${IMMICH_URL%/}/api"
AUTH="x-api-key: $IMMICH_API_KEY"

cmd="${1:-help}"
shift || true

case "$cmd" in
  status)
    version=$(curl -fsS -H "$AUTH" "$API/server/version")
    ping=$(curl -fsS -H "$AUTH" "$API/server/ping")
    jq -n --argjson v "$version" --argjson p "$ping" \
      '{version: "\($v.major)" + "." + "\($v.minor)" + "." + "\($v.patch)", versionParts: $v, ping: $p.res}'
    ;;

  stats|library-stats)
    curl -fsS -H "$AUTH" "$API/server/statistics" | jq '{
      photos, videos,
      usageBytes: .usage,
      usagePhotosBytes: .usagePhotos,
      usageVideosBytes: .usageVideos,
      perUser: [.usageByUser[] | {userId, userName, photos, videos, usageBytes: .usage, quotaSizeInBytes}]
    }'
    ;;

  storage)
    curl -fsS -H "$AUTH" "$API/server/storage"
    ;;

  users)
    # /api/admin/users returns isAdmin + quotaSizeInBytes; requires adminUser.read on the key.
    # Falls back to /api/users (no admin fields) if forbidden.
    if result=$(curl -fsS -H "$AUTH" "$API/admin/users" 2>/dev/null); then
      echo "$result" | jq '[.[] | {id, name, email, isAdmin, quotaSizeInBytes, quotaUsageInBytes, status}]'
    else
      curl -fsS -H "$AUTH" "$API/users" | jq '[.[] | {id, name, email}] | . + [{note: "admin fields unavailable: API key lacks adminUser.read"}]'
    fi
    ;;

  me)
    curl -fsS -H "$AUTH" "$API/users/me" | jq '{id, name, email, isAdmin, storageLabel, quotaSizeInBytes, quotaUsageInBytes}'
    ;;

  albums)
    n="${1:-25}"
    curl -fsS -H "$AUTH" "$API/albums" | jq --argjson n "$n" '[
      .[:$n][] | {id, albumName, assetCount, createdAt, ownerId}
    ]'
    ;;

  album-info)
    id="${1:?usage: album-info <id>}"
    curl -fsS -H "$AUTH" "$API/albums/$id"
    ;;

  search)
    query="${1:?usage: search <query>}"
    body=$(jq -n --arg q "$query" '{query: $q, size: 25}')
    # Try CLIP smart search first.
    if smart=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$body" "$API/search/smart" 2>/dev/null); then
      count=$(echo "$smart" | jq '.assets.count // 0')
      if [ "$count" -gt 0 ]; then
        echo "$smart" | jq '{
          mode: "smart",
          query: '"$(printf '%s' "$query" | jq -Rs .)"',
          total: .assets.total,
          count: .assets.count,
          items: [.assets.items[] | {id, type, originalFileName, fileCreatedAt, exifInfo: {make: .exifInfo.make, model: .exifInfo.model}}]
        }'
        exit 0
      fi
    fi
    # Fallback: metadata search by original filename substring.
    fallback_body=$(jq -n --arg q "$query" '{originalFileName: $q, size: 25}')
    curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$fallback_body" "$API/search/metadata" | jq '{
      mode: "metadata",
      query: '"$(printf '%s' "$query" | jq -Rs .)"',
      total: .assets.total,
      count: .assets.count,
      items: [.assets.items[] | {id, type, originalFileName, fileCreatedAt, exifInfo: {make: .exifInfo.make, model: .exifInfo.model}}]
    }'
    ;;

  recent)
    n="${1:-25}"
    body=$(jq -n --argjson n "$n" '{size: $n, order: "desc"}')
    curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$body" "$API/search/metadata" | jq '{
      total: .assets.total,
      count: .assets.count,
      items: [.assets.items[] | {id, originalFileName, fileCreatedAt, type, exifInfo: {make: .exifInfo.make, model: .exifInfo.model}}]
    }'
    ;;

  people)
    n="${1:-25}"
    curl -fsS -H "$AUTH" "$API/people?withHidden=false&size=$n" | jq '{
      total,
      hidden,
      hasNextPage,
      people: [.people[] | {id, name, birthDate, isFavorite, isHidden}]
    }'
    ;;

  person-info)
    id="${1:?usage: person-info <id>}"
    curl -fsS -H "$AUTH" "$API/people/$id"
    ;;

  jobs)
    curl -fsS -H "$AUTH" "$API/jobs" | jq 'to_entries | [.[] | {queue: .key, paused: .value.queueStatus.isPaused, active: .value.queueStatus.isActive, counts: .value.jobCounts}]'
    ;;

  tags)
    curl -fsS -H "$AUTH" "$API/tags" | jq '[.[] | {id, name, value}]'
    ;;

  help|--help|-h|"")
    cat <<EOF
immich.sh — wrapper for Immich v2.x API

env required: IMMICH_URL, IMMICH_API_KEY (from sops-nix)
header:       x-api-key (lowercase)

commands:
  status                GET /server/version + /server/ping (combined)
  stats                 GET /server/statistics (photos, videos, usage, per-user)
  storage               GET /server/storage (disk free / used)
  users                 GET /admin/users (id, name, email, isAdmin, quotaSizeInBytes)
                        falls back to /users if key lacks adminUser.read
  me                    GET /users/me
  albums [n]            GET /albums, first n (default 25)
  album-info <id>       GET /albums/<id>
  search <query>        POST /search/smart (CLIP), fallback POST /search/metadata
  recent [n]            POST /search/metadata (size n, order desc, default 25)
  people [n]            GET /people?withHidden=false&size=n (default 25)
  person-info <id>      GET /people/<id>
  jobs                  GET /jobs (background queue status)
  library-stats         alias for stats
  tags                  GET /tags
  help                  this message

read-only by design — no asset/people/album mutations. Confirm with the
user before adding any mutating sub-command (see SKILL.md).
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
