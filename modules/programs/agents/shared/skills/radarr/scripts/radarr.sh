#!/usr/bin/env bash
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${RADARR_URL:?RADARR_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${RADARR_API_KEY:?RADARR_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

DEFAULT_QUALITY_PROFILE="${RADARR_DEFAULT_QUALITY_PROFILE:-1}"
API="${RADARR_URL%/}/api/v3"
AUTH="X-Api-Key: $RADARR_API_KEY"

cmd="${1:-help}"
shift || true

urlencode() { jq -sRr @uri <<<"$1"; }

case "$cmd" in
  status)
    curl -fsS -H "$AUTH" "$API/system/status" | jq '{appName, version, instanceName, branch, runtimeVersion}'
    ;;

  config)
    echo "=== Root Folders ==="
    curl -fsS -H "$AUTH" "$API/rootfolder" | jq -r '.[] | "\(.id): \(.path)  (\(.freeSpace) bytes free)"'
    echo
    echo "=== Quality Profiles ==="
    curl -fsS -H "$AUTH" "$API/qualityprofile" | jq -r '.[] | "\(.id): \(.name)"'
    ;;

  search)
    query="${1:?usage: search <query>}"
    curl -fsS -H "$AUTH" "$API/movie/lookup?term=$(urlencode "$query")" | jq -r '
      to_entries | .[:10] | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year // "?")) [tmdb:\(.value.tmdbId)] - https://themoviedb.org/movie/\(.value.tmdbId)"
      + (if .value.collection.tmdbId then " [Collection: \(.value.collection.title)]" else "" end)
    '
    ;;

  search-json)
    query="${1:?usage: search-json <query>}"
    curl -fsS -H "$AUTH" "$API/movie/lookup?term=$(urlencode "$query")"
    ;;

  exists)
    tmdbId="${1:?usage: exists <tmdbId>}"
    result=$(curl -fsS -H "$AUTH" "$API/movie?tmdbId=$tmdbId")
    if [ "$result" = "[]" ]; then
      echo "not_found"
    else
      echo "exists"
      echo "$result" | jq -r '.[0] | "ID: \(.id), Title: \(.title) (\(.year)), Has File: \(.hasFile)"'
    fi
    ;;

  queue)
    curl -fsS -H "$AUTH" "$API/queue?pageSize=100&includeUnknownMovieItems=true&includeMovie=true" | jq '
      .records[] | {
        id,
        movie: (.movie.title // null),
        year: (.movie.year // null),
        title,
        size, sizeleft, status, trackedDownloadStatus,
        timeleft,
        errorMessage
      }'
    ;;

  calendar)
    days="${1:-30}"
    start=$(date -u +%Y-%m-%d)
    end=$(date -u -d "+${days} days" +%Y-%m-%d 2>/dev/null || date -u -v+"${days}"d +%Y-%m-%d)
    curl -fsS -H "$AUTH" "$API/calendar?start=${start}&end=${end}&unmonitored=false" | jq '[
      .[] | {title, year, inCinemas, physicalRelease, digitalRelease, hasFile, monitored}
    ]'
    ;;

  missing)
    n="${1:-100}"
    curl -fsS -H "$AUTH" "$API/wanted/missing?pageSize=${n}&monitored=true&sortKey=releaseDate&sortDirection=descending" | jq '
      .records[] | {title, year, inCinemas, physicalRelease, digitalRelease, status, isAvailable}
    '
    ;;

  history)
    n="${1:-50}"
    curl -fsS -H "$AUTH" "$API/history?pageSize=${n}&includeMovie=true&sortKey=date&sortDirection=descending" | jq '
      .records[] | {date, eventType, movie: (.movie.title // null), year: (.movie.year // null), quality: .quality.quality.name, sourceTitle}
    '
    ;;

  add)
    tmdbId="${1:?usage: add <tmdbId> [profileId] [--no-search]}"
    shift
    qualityProfileId=""
    searchFlag="true"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --no-search) searchFlag="false" ;;
        *) qualityProfileId="$1" ;;
      esac
      shift
    done

    movie=$(curl -fsS -H "$AUTH" "$API/movie/lookup?term=tmdb:$tmdbId" | jq '.[0]')
    if [ "$movie" = "null" ] || [ -z "$movie" ]; then
      echo "ERROR: no movie found with tmdbId=$tmdbId" >&2
      exit 1
    fi

    rootFolder=$(curl -fsS -H "$AUTH" "$API/rootfolder" | jq -r '.[0].path')
    if [ -z "$qualityProfileId" ]; then
      qualityProfileId="$DEFAULT_QUALITY_PROFILE"
    fi

    addRequest=$(jq -n \
      --argjson m "$movie" \
      --arg rf "$rootFolder" \
      --argjson qp "$qualityProfileId" \
      --argjson search "$searchFlag" '
      $m + {
        rootFolderPath: $rf,
        qualityProfileId: $qp,
        monitored: true,
        minimumAvailability: "released",
        addOptions: {
          searchForMovie: $search
        }
      }')

    result=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$addRequest" "$API/movie")
    if echo "$result" | jq -e '.id' >/dev/null 2>&1; then
      echo "$result" | jq '{id, title, year, path, monitored, searchTriggered: '"$searchFlag"'}'
    else
      echo "ERROR: failed to add movie" >&2
      echo "$result" | jq -r '.message // .' >&2
      exit 1
    fi
    ;;

  add-collection)
    collectionTmdbId="${1:?usage: add-collection <collectionTmdbId> [--no-search]}"
    shift
    searchFlag="true"
    [ "${1:-}" = "--no-search" ] && searchFlag="false"

    collections=$(curl -fsS -H "$AUTH" "$API/collection")
    collection=$(echo "$collections" | jq --argjson tid "$collectionTmdbId" '.[] | select(.tmdbId == $tid)')

    if [ -z "$collection" ] || [ "$collection" = "null" ]; then
      echo "ERROR: collection tmdbId=$collectionTmdbId not known to Radarr; add at least one of its movies first" >&2
      exit 1
    fi

    collectionTitle=$(echo "$collection" | jq -r '.title')
    searchTerm=$(echo "$collectionTitle" | sed 's/ Collection$//')

    allMovies=$(curl -fsS -H "$AUTH" "$API/movie/lookup?term=$(urlencode "$searchTerm")")
    moviesToAdd=$(echo "$allMovies" | jq --argjson cid "$collectionTmdbId" '[.[] | select(.collection.tmdbId == $cid)]')
    movieCount=$(echo "$moviesToAdd" | jq 'length')

    if [ "$movieCount" = "0" ]; then
      echo "ERROR: no movies found in collection $collectionTmdbId" >&2
      exit 1
    fi

    echo "Found $movieCount movies in collection: $collectionTitle"

    rootFolder=$(curl -fsS -H "$AUTH" "$API/rootfolder" | jq -r '.[0].path')
    qualityProfile="$DEFAULT_QUALITY_PROFILE"

    added=0
    skipped=0
    for i in $(seq 0 $((movieCount - 1))); do
      movie=$(echo "$moviesToAdd" | jq ".[$i]")
      tmdbId=$(echo "$movie" | jq -r '.tmdbId')
      title=$(echo "$movie" | jq -r '.title')
      year=$(echo "$movie" | jq -r '.year')

      existing=$(curl -fsS -H "$AUTH" "$API/movie?tmdbId=$tmdbId")
      if [ "$existing" != "[]" ]; then
        echo "skip: $title ($year) — already in library"
        skipped=$((skipped + 1))
        continue
      fi

      addRequest=$(echo "$movie" | jq --arg rf "$rootFolder" --argjson qp "$qualityProfile" --argjson search "$searchFlag" '
        . + {
          rootFolderPath: $rf,
          qualityProfileId: $qp,
          monitored: true,
          minimumAvailability: "released",
          addOptions: { searchForMovie: $search }
        }')

      result=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$addRequest" "$API/movie")
      if echo "$result" | jq -e '.id' >/dev/null 2>&1; then
        echo "add:  $title ($year)"
        added=$((added + 1))
      else
        echo "fail: $title ($year) — $(echo "$result" | jq -r '.message // "unknown error"')" >&2
      fi
    done

    echo
    echo "added=$added skipped=$skipped search=$searchFlag"

    collectionId=$(echo "$collection" | jq -r '.id')
    fullCollection=$(curl -fsS -H "$AUTH" "$API/collection/$collectionId")
    updatePayload=$(echo "$fullCollection" | jq '. + {monitored: true, searchOnAdd: true}')
    curl -fsS -X PUT -H "$AUTH" -H "Content-Type: application/json" -d "$updatePayload" "$API/collection/$collectionId" >/dev/null
    echo "collection monitored: future entries will be auto-added"
    ;;

  collection-info)
    tmdbId="${1:?usage: collection-info <collectionTmdbId>}"
    curl -fsS -H "$AUTH" "$API/collection" | jq --argjson tid "$tmdbId" '.[] | select(.tmdbId == $tid)'
    ;;

  remove)
    tmdbId="${1:?usage: remove <tmdbId> [--delete-files]}"
    shift
    deleteFiles="false"
    [ "${1:-}" = "--delete-files" ] && deleteFiles="true"

    movie=$(curl -fsS -H "$AUTH" "$API/movie?tmdbId=$tmdbId")
    if [ "$movie" = "[]" ]; then
      echo "ERROR: movie not in library (tmdbId=$tmdbId)" >&2
      exit 1
    fi

    movieId=$(echo "$movie" | jq -r '.[0].id')
    title=$(echo "$movie" | jq -r '.[0].title')
    year=$(echo "$movie" | jq -r '.[0].year')

    curl -fsS -X DELETE -H "$AUTH" \
      "$API/movie/${movieId}?deleteFiles=${deleteFiles}&addImportExclusion=false" >/dev/null

    if [ "$deleteFiles" = "true" ]; then
      echo "Removed: $title ($year) — files deleted"
    else
      echo "Removed: $title ($year) — files kept"
    fi
    ;;

  help|--help|-h|"")
    cat <<EOF
radarr.sh — wrapper for Radarr v3 API

env required: RADARR_URL, RADARR_API_KEY (from sops-nix)
env optional: RADARR_DEFAULT_QUALITY_PROFILE (default: 1)

commands:
  status                                       GET /system/status
  config                                       root folders + quality profiles
  search <query>                               TMDB lookup (top 10)
  search-json <query>                          same lookup, raw JSON
  exists <tmdbId>                              is movie in library?
  add <tmdbId> [profileId] [--no-search]       add movie (searches by default)
  add-collection <colTmdbId> [--no-search]     add all movies in a collection
  collection-info <colTmdbId>                  show Radarr's view of a collection
  remove <tmdbId> [--delete-files]             delete from library
  queue                                        active download queue
  calendar [days]                              upcoming releases (default 30)
  missing [n]                                  monitored movies with no file (default 100)
  history [n]                                  recent history (default 50)
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
