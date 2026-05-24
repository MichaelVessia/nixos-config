#!/usr/bin/env bash
set -euo pipefail

if command -v radarr >/dev/null 2>&1; then
  :
else
  printf 'radarr CLI not found in PATH. Rebuild nixos-config to install inputs.garage.packages.<system>.radarr.\n' >&2
  exit 127
fi

cmd="${1:-}"
if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
  exec radarr
fi

shift || true

case "$cmd" in
  search-json)
    exec radarr search "$@"
    ;;
  queue)
    if [[ "$#" -eq 0 ]]; then
      exec radarr queue --limit 100
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec radarr queue --limit "$1"
    fi
    exec radarr queue "$@"
    ;;
  calendar)
    if [[ "$#" -eq 0 ]]; then
      exec radarr calendar --days 30
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec radarr calendar --days "$1"
    fi
    exec radarr calendar "$@"
    ;;
  missing)
    if [[ "$#" -eq 0 ]]; then
      exec radarr missing --limit 100
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec radarr missing --limit "$1"
    fi
    exec radarr missing "$@"
    ;;
  history)
    if [[ "$#" -eq 0 ]]; then
      exec radarr history --limit 50
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec radarr history --limit "$1"
    fi
    exec radarr history "$@"
    ;;
  add)
    tmdb_id="${1:?usage: add <tmdbId> [profileId] [--no-search]}"
    shift
    args=(add "$tmdb_id")
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --no-search)
          args+=(--no-search)
          ;;
        --quality-profile)
          shift
          profile_id="${1:?usage: add <tmdbId> --quality-profile <profileId> [--no-search]}"
          args+=(--quality-profile "$profile_id")
          ;;
        *)
          args+=(--quality-profile "$1")
          ;;
      esac
      shift
    done
    exec radarr "${args[@]}"
    ;;
  status | config | search | exists | add-collection | collection-info | remove)
    exec radarr "$cmd" "$@"
    ;;
  *)
    exec radarr "$cmd" "$@"
    ;;
esac
