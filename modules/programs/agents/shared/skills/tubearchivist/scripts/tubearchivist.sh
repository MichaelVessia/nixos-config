#!/usr/bin/env bash
# TubeArchivist API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
#
# Auth: Django session + CSRF cookies. The wrapper caches the cookie jar
# in a per-user/per-URL tempfile and re-logs in if the jar is missing or
# the session is stale (TA session lifetime is 2 days by default).
set -euo pipefail

: "${TUBEARCHIVIST_URL:?TUBEARCHIVIST_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${TUBEARCHIVIST_USERNAME:?TUBEARCHIVIST_USERNAME not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${TUBEARCHIVIST_PASSWORD:?TUBEARCHIVIST_PASSWORD not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

BASE="${TUBEARCHIVIST_URL%/}"
API="$BASE/api"

# Per-user/per-URL cookie jar, persisted between invocations.
cache_key=$(printf '%s\n%s' "$TUBEARCHIVIST_URL" "$TUBEARCHIVIST_USERNAME" \
  | sha256sum | awk '{print $1}')
CACHE_DIR="${TMPDIR:-/tmp}/tubearchivist-$(id -u)"
JAR="$CACHE_DIR/${cache_key}.jar"

ensure_cache_dir() {
  mkdir -p "$CACHE_DIR"
  chmod 700 "$CACHE_DIR"
}

# Pull a cookie value out of the Netscape-format jar.
cookie_val() {
  local name="$1"
  [ -f "$JAR" ] || return 1
  awk -v n="$name" '$0 !~ /^#/ && $6 == n { print $7; found=1 } END { exit !found }' "$JAR"
}

# True iff we have a current sessionid cookie that isn't past its expiry.
session_fresh() {
  [ -f "$JAR" ] || return 1
  local now
  now=$(date +%s)
  awk -v n="sessionid" -v now="$now" '
    $0 !~ /^#/ && $6 == n {
      if ($5 == 0 || $5 > now + 30) { print "ok"; exit }
    }
  ' "$JAR" | grep -q ok
}

do_login() {
  ensure_cache_dir
  ( umask 077; : > "$JAR" )
  local body
  body=$(jq -n --arg u "$TUBEARCHIVIST_USERNAME" --arg p "$TUBEARCHIVIST_PASSWORD" \
    '{username:$u, password:$p}')
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -c "$JAR" -b "$JAR" \
    -H "Content-Type: application/json" \
    -X POST -d "$body" \
    "$API/user/login/")
  if [ "$code" != "204" ] && [ "$code" != "200" ]; then
    echo "ERROR: login failed (HTTP $code)" >&2
    exit 1
  fi
}

login() {
  if session_fresh; then
    return 0
  fi
  do_login
}

# GET helper: cookie jar only.
api_get() {
  local path="$1"
  login
  curl -fsS -b "$JAR" "$API$path"
}

# Mutating helper: send CSRF + Referer alongside cookies.
api_send() {
  local method="$1" path="$2" body="${3:-}"
  login
  local csrf
  csrf=$(cookie_val csrftoken) || { echo "ERROR: no csrftoken in jar" >&2; exit 1; }
  if [ -n "$body" ]; then
    curl -fsS -X "$method" \
      -b "$JAR" -c "$JAR" \
      -H "Content-Type: application/json" \
      -H "X-CSRFToken: $csrf" \
      -H "Referer: $BASE/" \
      -d "$body" \
      "$API$path"
  else
    curl -fsS -X "$method" \
      -b "$JAR" -c "$JAR" \
      -H "X-CSRFToken: $csrf" \
      -H "Referer: $BASE/" \
      "$API$path"
  fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  status)
    login
    health=$(curl -fsS -b "$JAR" "$API/health/" 2>/dev/null || echo '"unknown"')
    cfg=$(api_get /appsettings/config/)
    sv=$(api_get /stats/video/)
    sc=$(api_get /stats/channel/)
    sd=$(api_get /stats/download/)
    sw=$(api_get /stats/watch/)
    jq -n \
      --argjson health "$health" \
      --argjson config "$cfg" \
      --argjson video "$sv" \
      --argjson channel "$sc" \
      --argjson download "$sd" \
      --argjson watch "$sw" \
      --arg base "$BASE" '
        {
          url: $base,
          health: $health,
          config: $config,
          stats: { video: $video, channel: $channel, download: $download, watch: $watch }
        }'
    ;;

  channels)
    api_get /channel/ | jq '[.data[] | {
      name: .channel_name,
      id: .channel_id,
      subscribed: .channel_subscribed,
      last_refresh: .channel_last_refresh
    }]'
    ;;

  channel-info)
    channel_id="${1:?usage: channel-info <channel_id>}"
    api_get "/channel/$channel_id/" | jq
    ;;

  subscribe)
    target="${1:?usage: subscribe <url-or-channel_id>}"
    body=$(jq -n --arg t "$target" '{data:[{channel_id:$t, channel_subscribed:true}]}')
    api_send POST /channel/ "$body" | jq
    echo "Subscribe task queued. Run 'tasks' to inspect Celery progress." >&2
    ;;

  unsubscribe)
    channel_id="${1:?usage: unsubscribe <channel_id>}"
    body=$(jq -n --arg t "$channel_id" '{data:[{channel_id:$t, channel_subscribed:false}]}')
    api_send POST /channel/ "$body" | jq
    ;;

  videos)
    n="${1:-25}"
    api_get "/video/?page=0" | jq --argjson n "$n" '
      [.data[] | {
        youtube_id: .youtube_id,
        title: .title,
        channel: .channel.channel_name,
        published: .published,
        vid_type: .vid_type,
        watched: .player.watched
      }] | .[:$n]'
    ;;

  video-info)
    youtube_id="${1:?usage: video-info <youtube_id>}"
    api_get "/video/$youtube_id/" | jq
    ;;

  downloads)
    api_get /download/ | jq '{
      total: .paginate.total_hits,
      page_size: .paginate.page_size,
      items: [.data[] | {
        youtube_id: .youtube_id,
        title: .title,
        channel: .channel_name,
        status: .status,
        vid_type: .vid_type
      }]
    }'
    ;;

  playlists)
    api_get /playlist/ | jq '{
      total: .paginate.total_hits,
      items: [.data[] | {
        playlist_id: .playlist_id,
        name: .playlist_name,
        channel: .playlist_channel,
        subscribed: .playlist_subscribed,
        entries: (.playlist_entries | length // 0)
      }]
    }'
    ;;

  tasks)
    api_get /task/by-name/ | jq '[.[] | {
      name, status, date_done,
      args, kwargs,
      task_id,
      error: (if .status == "FAILURE" then .result else null end)
    }]'
    ;;

  search)
    query="${1:?usage: search <query>}"
    # /api/search/ hits all indexes (videos, channels, playlists, fulltext).
    encoded=$(jq -rn --arg v "$query" '$v|@uri')
    api_get "/search/?query=$encoded" | jq '{
      query_type: .queryType,
      videos: [.results.video_results // [] | .[] | {
        youtube_id: .youtube_id, title: .title,
        channel: .channel.channel_name, published: .published
      }],
      channels: [.results.channel_results // [] | .[] | {
        channel_id: .channel_id, name: .channel_name,
        subscribed: .channel_subscribed
      }],
      playlists: [.results.playlist_results // [] | .[] | {
        playlist_id: .playlist_id, name: .playlist_name
      }]
    }'
    ;;

  help|--help|-h|"")
    cat <<EOF
tubearchivist.sh — wrapper for TubeArchivist API (session + CSRF cookies)

env required:
  TUBEARCHIVIST_URL, TUBEARCHIVIST_USERNAME, TUBEARCHIVIST_PASSWORD (from sops-nix)

commands:
  status                       health + config + stats (video/channel/download/watch)
  channels                     list subscribed channels
  channel-info <channel_id>    detail for one channel
  subscribe <url-or-id>        subscribe (queues Celery task)
  unsubscribe <channel_id>     unsubscribe (confirm with user first!)
  videos [n]                   recent indexed videos (default 25)
  video-info <youtube_id>      detail for one video
  downloads                    pending download queue
  playlists                    indexed playlists
  tasks                        Celery task history (by-name)
  search <query>               cross-index search (videos, channels, playlists)
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
