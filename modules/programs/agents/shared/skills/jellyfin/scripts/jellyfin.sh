#!/usr/bin/env bash
# Jellyfin API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${JELLYFIN_URL:?JELLYFIN_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${JELLYFIN_API_KEY:?JELLYFIN_API_KEY not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${JELLYFIN_URL%/}"
AUTH="X-Emby-Token: $JELLYFIN_API_KEY"

cmd="${1:-help}"
shift || true

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

# Pick the first non-system user id (Jellyfin's "Latest Items" needs a userId).
pick_user_id() {
  curl -fsS -H "$AUTH" "$API/Users" \
    | jq -r '[.[] | select(.Policy.IsDisabled != true)] | .[0].Id'
}

case "$cmd" in
  status)
    curl -fsS -H "$AUTH" "$API/System/Info" \
      | jq '{ServerName, Version, Id, OperatingSystem, ProductName, LocalAddress}'
    ;;

  users)
    curl -fsS -H "$AUTH" "$API/Users" | jq '[
      .[] | {
        id: .Id,
        name: .Name,
        lastActivityDate: .LastActivityDate,
        isAdministrator: .Policy.IsAdministrator
      }
    ]'
    ;;

  libraries)
    curl -fsS -H "$AUTH" "$API/Library/VirtualFolders" | jq '[
      .[] | {
        name: .Name,
        collectionType: .CollectionType,
        itemId: .ItemId,
        locations: .Locations
      }
    ]'
    ;;

  sessions)
    curl -fsS -H "$AUTH" "$API/Sessions" | jq '[
      .[] | {
        sessionId: .Id,
        user: .UserName,
        client: .Client,
        device: .DeviceName,
        appVersion: .ApplicationVersion,
        lastActivityDate: .LastActivityDate,
        nowPlaying: (.NowPlayingItem.Name // null),
        playMethod: (.PlayState.PlayMethod // null)
      }
    ]'
    ;;

  now-playing)
    curl -fsS -H "$AUTH" "$API/Sessions" | jq '[
      .[] | select(.NowPlayingItem != null) | {
        user: .UserName,
        device: .DeviceName,
        client: .Client,
        item: .NowPlayingItem.Name,
        type: .NowPlayingItem.Type,
        series: (.NowPlayingItem.SeriesName // null),
        season: (.NowPlayingItem.ParentIndexNumber // null),
        episode: (.NowPlayingItem.IndexNumber // null),
        positionTicks: .PlayState.PositionTicks,
        runtimeTicks: .NowPlayingItem.RunTimeTicks,
        isPaused: .PlayState.IsPaused,
        playMethod: .PlayState.PlayMethod
      }
    ]'
    ;;

  recently-added)
    n="${1:-20}"
    uid=$(pick_user_id)
    if [ -z "$uid" ] || [ "$uid" = "null" ]; then
      echo "ERROR: no usable user found" >&2
      exit 1
    fi
    curl -fsS -H "$AUTH" "$API/Users/$uid/Items/Latest?Limit=$n" | jq '[
      .[] | {
        id: .Id,
        name: .Name,
        type: .Type,
        series: (.SeriesName // null),
        season: (.ParentIndexNumber // null),
        episode: (.IndexNumber // null),
        dateCreated: .DateCreated,
        productionYear: (.ProductionYear // null)
      }
    ]'
    ;;

  item-search)
    query="${1:?usage: item-search <query>}"
    uid=$(pick_user_id)
    if [ -z "$uid" ] || [ "$uid" = "null" ]; then
      echo "ERROR: no usable user found" >&2
      exit 1
    fi
    curl -fsS -H "$AUTH" \
      "$API/Users/$uid/Items?searchTerm=$(urlencode "$query")&Recursive=true&IncludeItemTypes=Movie,Series,Episode&Limit=25" \
      | jq '[
        .Items[] | {
          id: .Id,
          name: .Name,
          type: .Type,
          series: (.SeriesName // null),
          season: (.ParentIndexNumber // null),
          episode: (.IndexNumber // null),
          productionYear: (.ProductionYear // null)
        }
      ]'
    ;;

  library-stats)
    curl -fsS -H "$AUTH" "$API/Items/Counts" | jq
    ;;

  scheduled-tasks)
    curl -fsS -H "$AUTH" "$API/ScheduledTasks" | jq '[
      .[] | {
        id: .Id,
        name: .Name,
        state: .State,
        lastExecutionResult: (.LastExecutionResult.Status // null),
        lastEndTime: (.LastExecutionResult.EndTimeUtc // null),
        category: .Category
      }
    ]'
    ;;

  run-task)
    taskId="${1:?usage: run-task <taskId>}"
    curl -fsS -X POST -H "$AUTH" "$API/ScheduledTasks/Running/$taskId" -o /dev/null -w "%{http_code}\n"
    ;;

  help|--help|-h|"")
    cat <<EOF
jellyfin.sh — wrapper for Jellyfin API

env required: JELLYFIN_URL, JELLYFIN_API_KEY (from sops-nix)

commands:
  status                       GET /System/Info
  users                        GET /Users (id, name, lastActivityDate, isAdministrator)
  libraries                    GET /Library/VirtualFolders
  sessions                     GET /Sessions (all active sessions)
  now-playing                  Sessions filtered to those with NowPlayingItem
  recently-added [n]           GET /Users/<uid>/Items/Latest?Limit=n (default 20)
  item-search <query>          Search Movies/Series/Episodes for the first user
  library-stats                GET /Items/Counts
  scheduled-tasks              GET /ScheduledTasks
  run-task <taskId>            POST /ScheduledTasks/Running/<id> (confirm first)
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
