#!/usr/bin/env bash
set -euo pipefail

if command -v sonarr >/dev/null 2>&1; then
  :
else
  printf 'sonarr CLI not found in PATH. Rebuild nixos-config to install inputs.garage.packages.<system>.sonarr.\n' >&2
  exit 127
fi

cmd="${1:-}"
if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" || "$cmd" == "-h" ]]; then
  exec sonarr
fi

shift || true

case "$cmd" in
  search-json)
    exec sonarr search "$@"
    ;;
  queue)
    if [[ "$#" -eq 0 ]]; then
      exec sonarr queue --limit 100
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec sonarr queue --limit "$1"
    fi
    exec sonarr queue "$@"
    ;;
  calendar)
    if [[ "$#" -eq 0 ]]; then
      exec sonarr calendar --days 14
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec sonarr calendar --days "$1"
    fi
    exec sonarr calendar "$@"
    ;;
  missing)
    if [[ "$#" -eq 0 ]]; then
      exec sonarr missing --limit 100
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec sonarr missing --limit "$1"
    fi
    exec sonarr missing "$@"
    ;;
  history)
    if [[ "$#" -eq 0 ]]; then
      exec sonarr history --limit 50
    fi
    if [[ "$#" -eq 1 && "$1" != --* ]]; then
      exec sonarr history --limit "$1"
    fi
    exec sonarr history "$@"
    ;;
  add)
    tvdb_id="${1:?usage: add <tvdbId> [profileId] [--no-search]}"
    shift
    args=(add "$tvdb_id")
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --no-search)
          args+=(--no-search)
          ;;
        --quality-profile)
          shift
          profile_id="${1:?usage: add <tvdbId> --quality-profile <profileId> [--no-search]}"
          args+=(--quality-profile "$profile_id")
          ;;
        *)
          args+=(--quality-profile "$1")
          ;;
      esac
      shift
    done
    exec sonarr "${args[@]}"
    ;;
  status | config | search | exists | remove)
    exec sonarr "$cmd" "$@"
    ;;
  *)
    exec sonarr "$cmd" "$@"
    ;;
esac
