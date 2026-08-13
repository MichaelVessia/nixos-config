#!/usr/bin/env bash
set -euo pipefail

: "${PROWLARR_URL:?PROWLARR_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${PROWLARR_API_KEY:?PROWLARR_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${PROWLARR_URL%/}/api/v1"
AUTH="X-Api-Key: $PROWLARR_API_KEY"

cmd="${1:-help}"
shift || true

urlencode() { jq -sRr @uri <<<"$1"; }

api_get() { curl -fsS -H "$AUTH" "$API$1"; }
api_post() { curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$2" "$API$1"; }
api_put() { curl -fsS -X PUT -H "$AUTH" -H "Content-Type: application/json" -d "$2" "$API$1"; }
api_delete() { curl -fsS -X DELETE -H "$AUTH" "$API$1"; }

case "$cmd" in
  status)
    api_get "/system/status" | jq '{appName, version, instanceName, branch, runtimeVersion, osName}'
    ;;

  health)
    api_get "/health" | jq '[.[] | {source, type, message, wikiUrl}]'
    ;;

  indexers)
    verbose="false"
    [ "${1:-}" = "--verbose" ] && verbose="true"
    if [ "$verbose" = "true" ]; then
      api_get "/indexer"
    else
      api_get "/indexer" | jq '[.[] | {id, name, protocol, enable, priority, supportsSearch, supportsRss}]'
    fi
    ;;

  indexer-stats|stats)
    api_get "/indexerstats" | jq '.indexers | [.[] | {
      id: .indexerId,
      name: .indexerName,
      queries: .numberOfQueries,
      grabs: .numberOfGrabs,
      failedQueries: .numberOfFailedQueries,
      failedGrabs: .numberOfFailedGrabs,
      avgResponseTimeMs: .averageResponseTime
    }]'
    ;;

  search)
    query=""
    indexer_ids=""
    categories=""
    limit=""
    type_param="search"
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --torrents) indexer_ids="-2"; shift ;;
        --usenet) indexer_ids="-1"; shift ;;
        --category|-c) categories="$2"; shift 2 ;;
        --limit|-l) limit="$2"; shift 2 ;;
        --type|-t) type_param="$2"; shift 2 ;;
        --*) echo "unknown flag: $1" >&2; exit 2 ;;
        *) [ -z "$query" ] && query="$1" || query="$query $1"; shift ;;
      esac
    done
    : "${query:?usage: search <query> [--torrents|--usenet] [--category <id>] [--limit <n>]}"

    params="query=$(urlencode "$query")&type=${type_param}"
    [ -n "$indexer_ids" ] && params="${params}&indexerIds=${indexer_ids}"
    [ -n "$categories" ] && params="${params}&categories=${categories}"
    [ -n "$limit" ] && params="${params}&limit=${limit}"

    api_get "/search?${params}" | jq '[.[] | {
      title,
      indexer,
      protocol,
      sizeMB: (if .size then (.size / 1048576 | floor) else null end),
      seeders,
      leechers,
      grabs,
      age,
      publishDate,
      downloadUrl,
      infoUrl,
      categories
    }]'
    ;;

  tv-search)
    tvdb=""
    season=""
    episode=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --tvdb) tvdb="$2"; shift 2 ;;
        --season|-s) season="$2"; shift 2 ;;
        --episode|-e) episode="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
      esac
    done
    : "${tvdb:?usage: tv-search --tvdb <id> [--season <n>] [--episode <n>]}"

    q="{TvdbId:${tvdb}}"
    [ -n "$season" ] && q="${q} {Season:${season}}"
    [ -n "$episode" ] && q="${q} {Episode:${episode}}"

    api_get "/search?query=$(urlencode "$q")&type=tvsearch" | jq '[.[] | {
      title,
      indexer,
      protocol,
      sizeMB: (if .size then (.size / 1048576 | floor) else null end),
      seeders,
      age,
      publishDate,
      downloadUrl
    }]'
    ;;

  movie-search)
    imdb=""
    tmdb=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --imdb) imdb="$2"; shift 2 ;;
        --tmdb) tmdb="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
      esac
    done

    if [ -z "$imdb" ] && [ -z "$tmdb" ]; then
      echo "usage: movie-search --imdb <id> | --tmdb <id>" >&2
      exit 2
    fi

    q=""
    [ -n "$imdb" ] && q="{ImdbId:${imdb}}"
    [ -n "$tmdb" ] && q="${q}{TmdbId:${tmdb}}"

    api_get "/search?query=$(urlencode "$q")&type=movie" | jq '[.[] | {
      title,
      indexer,
      protocol,
      sizeMB: (if .size then (.size / 1048576 | floor) else null end),
      seeders,
      age,
      publishDate,
      downloadUrl
    }]'
    ;;

  test)
    id="${1:?usage: test <indexerId>}"
    body=$(api_get "/indexer/${id}")
    response=$(curl -sS -o /tmp/prowlarr-test-$$.json -w '%{http_code}' \
      -X POST -H "$AUTH" -H "Content-Type: application/json" \
      -d "$body" "$API/indexer/test")
    code="$response"
    out=$(cat /tmp/prowlarr-test-$$.json)
    rm -f /tmp/prowlarr-test-$$.json
    if [ "$code" = "200" ] || [ "$code" = "202" ]; then
      echo "{\"indexerId\": ${id}, \"status\": \"ok\", \"httpCode\": ${code}}"
    else
      echo "{\"indexerId\": ${id}, \"status\": \"failed\", \"httpCode\": ${code}, \"body\": ${out:-null}}"
      exit 1
    fi
    ;;

  apps|applications)
    api_get "/applications" | jq '[.[] | {id, name, implementation, syncLevel, tags}]'
    ;;

  sync)
    api_post "/command" '{"name":"ApplicationIndexerSync"}' | jq '{id, name, status, queued}'
    ;;

  history)
    n="${1:-50}"
    api_get "/history?page=1&pageSize=${n}&sortKey=date&sortDirection=descending" | jq '
      .records[] | {
        date,
        eventType,
        indexerId,
        successful: (.data.successful // null),
        query: (.data.query // null),
        queryType: (.data.queryType // null),
        results: (.data.results // null),
        elapsedTime: (.data.elapsedTime // null)
      }'
    ;;

  help|--help|-h|"")
    cat <<EOF
prowlarr.sh — wrapper for Prowlarr v1 API

env required: PROWLARR_URL, PROWLARR_API_KEY (from sops-nix)

commands:
  status                                  GET /system/status
  health                                  active health warnings
  indexers [--verbose]                    list indexers (summary or full)
  indexer-stats | stats                   per-indexer query/grab/failure counts
  search <query> [filters]                search all indexers
    filters: --torrents | --usenet | --category <id> | --limit <n>
  tv-search --tvdb <id> [--season <n>] [--episode <n>]
                                          TV search via TVDB ID
  movie-search --imdb <id> | --tmdb <id>  movie search via IMDB or TMDB ID
  test <indexerId>                        test a specific indexer
  apps | applications                     connected apps (Sonarr/Radarr/...)
  sync                                    push indexer config to all apps
  history [n]                             recent indexer history (default 50)

categories: 2000=Movies 5000=TV 3000=Audio 7000=Books 1000=Console 4000=PC
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
