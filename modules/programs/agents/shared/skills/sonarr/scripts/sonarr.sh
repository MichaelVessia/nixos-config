#!/usr/bin/env bash
# Sonarr API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${SONARR_URL:?SONARR_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${SONARR_API_KEY:?SONARR_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

DEFAULT_QUALITY_PROFILE="${SONARR_DEFAULT_QUALITY_PROFILE:-1}"
API="${SONARR_URL%/}/api/v3"
AUTH="X-Api-Key: $SONARR_API_KEY"

cmd="${1:-help}"
shift || true

# urlencode a string via jq (no python dep)
urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

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
    curl -fsS -H "$AUTH" "$API/series/lookup?term=$(urlencode "$query")" | jq -r '
      to_entries | .[:10] | .[] |
      "\(.key + 1). \(.value.title) (\(.value.year // "?")) [tvdb:\(.value.tvdbId)] - https://thetvdb.com/dereferrer/series/\(.value.tvdbId)"
    '
    ;;

  search-json)
    query="${1:?usage: search-json <query>}"
    curl -fsS -H "$AUTH" "$API/series/lookup?term=$(urlencode "$query")"
    ;;

  exists)
    tvdbId="${1:?usage: exists <tvdbId>}"
    result=$(curl -fsS -H "$AUTH" "$API/series?tvdbId=$tvdbId")
    if [ "$result" = "[]" ]; then
      echo "not_found"
    else
      echo "exists"
      echo "$result" | jq -r '.[0] | "ID: \(.id), Title: \(.title), Seasons: \(.statistics.seasonCount // "?")"'
    fi
    ;;

  queue)
    curl -fsS -H "$AUTH" "$API/queue?pageSize=100&includeUnknownSeriesItems=true" | jq '
      .records[] | {
        id,
        series: (.series.title // null),
        episode: (.episode.title // null),
        season: (.episode.seasonNumber // null),
        ep: (.episode.episodeNumber // null),
        size, sizeleft, status, trackedDownloadStatus,
        errorMessage
      }'
    ;;

  calendar)
    days="${1:-14}"
    start=$(date -u +%Y-%m-%d)
    end=$(date -u -d "+${days} days" +%Y-%m-%d 2>/dev/null || date -u -v+"${days}"d +%Y-%m-%d)
    curl -fsS -H "$AUTH" "$API/calendar?start=${start}&end=${end}&includeSeries=true" | jq '[
      .[] | {airDate, series: .series.title, season: .seasonNumber, ep: .episodeNumber, title, hasFile, monitored}
    ]'
    ;;

  missing)
    n="${1:-100}"
    curl -fsS -H "$AUTH" "$API/wanted/missing?pageSize=${n}&monitored=true&includeSeries=true&sortKey=airDateUtc&sortDirection=descending" | jq '
      .records[] | {series: .series.title, season: .seasonNumber, ep: .episodeNumber, title, airDate: .airDateUtc}
    '
    ;;

  history)
    n="${1:-50}"
    curl -fsS -H "$AUTH" "$API/history?pageSize=${n}&sortKey=date&sortDirection=descending" | jq '
      .records[] | {date, eventType, series: .series.title, episode: (.episode.title // null), quality: .quality.quality.name, sourceTitle}
    '
    ;;

  add)
    tvdbId="${1:?usage: add <tvdbId> [profileId] [--no-search]}"
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

    series=$(curl -fsS -H "$AUTH" "$API/series/lookup?term=tvdb:$tvdbId" | jq '.[0]')
    if [ "$series" = "null" ] || [ -z "$series" ]; then
      echo "ERROR: no show found with tvdbId=$tvdbId" >&2
      exit 1
    fi

    rootFolder=$(curl -fsS -H "$AUTH" "$API/rootfolder" | jq -r '.[0].path')
    if [ -z "$qualityProfileId" ]; then
      qualityProfileId="$DEFAULT_QUALITY_PROFILE"
    fi

    addRequest=$(jq -n \
      --argjson s "$series" \
      --arg rf "$rootFolder" \
      --argjson qp "$qualityProfileId" \
      --argjson search "$searchFlag" '
      $s + {
        rootFolderPath: $rf,
        qualityProfileId: $qp,
        monitored: true,
        seasonFolder: true,
        addOptions: {
          monitor: "all",
          searchForMissingEpisodes: $search,
          searchForCutoffUnmetEpisodes: false
        }
      }')

    result=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$addRequest" "$API/series")
    if echo "$result" | jq -e '.id' >/dev/null 2>&1; then
      echo "$result" | jq '{id, title, year, path, monitored, searchTriggered: '"$searchFlag"'}'
    else
      echo "ERROR: failed to add show" >&2
      echo "$result" | jq -r '.message // .' >&2
      exit 1
    fi
    ;;

  remove)
    tvdbId="${1:?usage: remove <tvdbId> [--delete-files]}"
    shift
    deleteFiles="false"
    [ "${1:-}" = "--delete-files" ] && deleteFiles="true"

    series=$(curl -fsS -H "$AUTH" "$API/series?tvdbId=$tvdbId")
    if [ "$series" = "[]" ]; then
      echo "ERROR: show not in library (tvdbId=$tvdbId)" >&2
      exit 1
    fi

    seriesId=$(echo "$series" | jq -r '.[0].id')
    title=$(echo "$series" | jq -r '.[0].title')
    year=$(echo "$series" | jq -r '.[0].year')

    curl -fsS -X DELETE -H "$AUTH" \
      "$API/series/${seriesId}?deleteFiles=${deleteFiles}&addImportListExclusion=false" >/dev/null

    if [ "$deleteFiles" = "true" ]; then
      echo "Removed: $title ($year) — files deleted"
    else
      echo "Removed: $title ($year) — files kept"
    fi
    ;;

  help|--help|-h|"")
    cat <<EOF
sonarr.sh — wrapper for Sonarr v3 API

env required: SONARR_URL, SONARR_API_KEY (from sops-nix)
env optional: SONARR_DEFAULT_QUALITY_PROFILE (default: 1)

commands:
  status                                  GET /system/status
  config                                  root folders + quality profiles
  search <query>                          TVDB lookup (top 10)
  search-json <query>                     same lookup, raw JSON
  exists <tvdbId>                         is show in library?
  add <tvdbId> [profileId] [--no-search]  add show (searches by default)
  remove <tvdbId> [--delete-files]        delete from library
  queue                                   active download queue
  calendar [days]                         upcoming releases (default 14)
  missing [n]                             monitored episodes with no file (default 100)
  history [n]                             recent history (default 50)
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
