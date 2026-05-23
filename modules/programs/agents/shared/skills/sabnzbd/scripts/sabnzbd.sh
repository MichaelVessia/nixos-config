#!/usr/bin/env bash
set -euo pipefail

: "${SABNZBD_URL:?SABNZBD_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${SABNZBD_API_KEY:?SABNZBD_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

BASE="${SABNZBD_URL%/}/api"

call() {
  local mode="$1"
  shift
  local url="${BASE}?apikey=${SABNZBD_API_KEY}&output=json&mode=${mode}"
  for p in "$@"; do
    url+="&${p}"
  done
  curl -fsS "$url"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  status)
    call fullstatus | jq '.status | {
      version, uptime, paused, paused_all,
      speedlimit, speedlimit_abs,
      diskspace1_norm, diskspace2_norm,
      have_warnings, warnings,
      new_release
    }'
    ;;

  version)
    call version
    ;;

  queue)
    call queue | jq '.queue | {
      status, paused, speed, speedlimit, timeleft,
      mb, mbleft, noofslots,
      slots: [.slots[] | {
        nzo_id, filename, status, priority, cat,
        mb, mbleft, percentage, timeleft
      }]
    }'
    ;;

  history)
    n="${1:-50}"
    call history "limit=${n}" | jq '.history | {
      total_size, month_size, week_size, day_size, noofslots,
      slots: [.slots[] | {
        nzo_id, name, status, category, bytes, fail_message, storage, completed
      }]
    }'
    ;;

  pause)
    call pause | jq .
    ;;

  resume)
    call resume | jq .
    ;;

  delete)
    nzo_id="${1:?usage: delete <nzo_id> [--files]}"
    shift || true
    del_files="0"
    [ "${1:-}" = "--files" ] && del_files="1"
    call queue "name=delete" "value=${nzo_id}" "del_files=${del_files}" | jq .
    ;;

  server-stats)
    call server_stats | jq '{total, month, week, day, servers}'
    ;;

  help|--help|-h|"")
    cat <<EOF
sabnzbd.sh - wrapper for SABnzbd HTTP API

env required: SABNZBD_URL, SABNZBD_API_KEY (from sops-nix)

commands:
  status                       full status snapshot
  version                      SABnzbd version
  queue                        active download queue
  history [n]                  recent history (default 50)
  pause                        pause queue
  resume                       resume queue
  delete <nzo_id> [--files]    remove queue item (optionally delete files)
  server-stats                 download totals (day/week/month/total)
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
