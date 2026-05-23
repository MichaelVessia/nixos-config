#!/usr/bin/env bash
# Workflow: subscribe a YouTube channel in TubeArchivist, queue its top videos
# by views from recent uploads, wait for the first file, scan Jellyfin, and
# rename + lock the Jellyfin folder to a friendly display name.
#
# Credentials come from the shell via sops-nix (see modules/programs/shell.nix).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: add-youtube-channel.sh <handle-or-url> <friendly-name> [--top N] [--recent K] [--resolve-only]

Positional:
  <handle-or-url>   YouTube channel handle (@example), URL, or UC... channel id
  <friendly-name>   Display name to set in Jellyfin (quoted)

Options:
  --top N           Number of top-viewed videos to queue (default 20)
  --recent K        How many recent uploads to sample by views (default 30)
  --resolve-only    Only run the yt-dlp handle resolution step and print JSON

Env required (from sops-nix):
  TUBEARCHIVIST_URL TUBEARCHIVIST_USERNAME TUBEARCHIVIST_PASSWORD
  JELLYFIN_URL JELLYFIN_API_KEY
EOF
}

if [ $# -lt 1 ]; then
  usage >&2
  exit 2
fi

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
esac

TOP=20
RECENT=30
RESOLVE_ONLY=0
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --top)
      TOP="${2:?--top needs a value}"; shift 2 ;;
    --recent)
      RECENT="${2:?--recent needs a value}"; shift 2 ;;
    --resolve-only)
      RESOLVE_ONLY=1; shift ;;
    --)
      shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*)
      echo "unknown flag: $1" >&2; usage >&2; exit 2 ;;
    *)
      POS+=("$1"); shift ;;
  esac
done

if [ "$RESOLVE_ONLY" -eq 1 ]; then
  if [ "${#POS[@]}" -lt 1 ]; then
    echo "ERROR: --resolve-only still needs <handle-or-url>" >&2
    exit 2
  fi
  HANDLE="${POS[0]}"
  FRIENDLY="${POS[1]:-}"
else
  if [ "${#POS[@]}" -lt 2 ]; then
    usage >&2
    exit 2
  fi
  HANDLE="${POS[0]}"
  FRIENDLY="${POS[1]}"
fi

if [ "$RESOLVE_ONLY" -ne 1 ]; then
  : "${TUBEARCHIVIST_URL:?TUBEARCHIVIST_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
  : "${TUBEARCHIVIST_USERNAME:?TUBEARCHIVIST_USERNAME not set.}"
  : "${TUBEARCHIVIST_PASSWORD:?TUBEARCHIVIST_PASSWORD not set.}"
  : "${JELLYFIN_URL:?JELLYFIN_URL not set.}"
  : "${JELLYFIN_API_KEY:?JELLYFIN_API_KEY not set.}"
fi

TA_BASE="${TUBEARCHIVIST_URL:-}"; TA_BASE="${TA_BASE%/}"
TA_API="$TA_BASE/api"
JF_API="${JELLYFIN_URL:-}"; JF_API="${JF_API%/}"
JF_AUTH="X-Emby-Token: ${JELLYFIN_API_KEY:-}"

SSH_TARGET="proxmox"
LXC_ID="120"
YTDLP="/opt/tubearchivist/.venv/bin/yt-dlp"
# Modern yt-dlp needs a JS runtime to extract per-video fields (view_count).
# Deno is installed in the LXC but yt-dlp doesn't auto-discover its path.
JS_RUNTIME="deno:/usr/local/bin/deno"
MEDIA_ROOT="/mnt/media/youtube"

ts() { date '+%H:%M:%S'; }
log() { printf '[%s] %s\n' "$(ts)" "$*" >&2; }

# Build the channel URL we hand to yt-dlp. yt-dlp accepts @handles, /channel/UC...,
# and bare UC... ids. We normalize to a URL so the SSH command is unambiguous.
normalize_target() {
  local raw="$1"
  case "$raw" in
    http*://*) printf '%s' "$raw" ;;
    @*)        printf 'https://www.youtube.com/%s' "$raw" ;;
    UC*)       printf 'https://www.youtube.com/channel/%s' "$raw" ;;
    *)         printf 'https://www.youtube.com/@%s' "$raw" ;;
  esac
}

# Remote yt-dlp invocation. We use TA's bundled binary so the workstation does
# not need yt-dlp installed and we get the same cookies / extractor version.
# --js-runtimes is required for per-video field extraction (e.g. view_count).
remote_ytdlp() {
  ssh -o BatchMode=yes "$SSH_TARGET" \
    "pct exec $LXC_ID -- $YTDLP --js-runtimes $JS_RUNTIME $*"
}

resolve_channel() {
  local target="$1"
  # Grab one entry in flat-playlist mode; in flat mode yt-dlp exposes channel
  # info under playlist_* keys. Cheap (1 item, no download) and fails loudly
  # on bad handles (404 from the resolver).
  remote_ytdlp --skip-download --flat-playlist --playlist-items 1 \
    --print-json "'$target'" 2>/dev/null \
    | jq -c '{
        channel_id: (.playlist_channel_id // .channel_id),
        channel: (.playlist_channel // .channel),
        uploader_id: (.playlist_uploader_id // .uploader_id),
        webpage_url
      }'
}

# Cookie jar caching for TubeArchivist (same pattern as tubearchivist.sh).
# Lazily initialized once we know we'll need a TA session.
JAR=""
init_jar() {
  [ -n "$JAR" ] && return 0
  local key
  key=$(printf '%s\n%s' "$TUBEARCHIVIST_URL" "$TUBEARCHIVIST_USERNAME" \
    | sha256sum | awk '{print $1}')
  CACHE_DIR="${TMPDIR:-/tmp}/tubearchivist-$(id -u)"
  JAR="$CACHE_DIR/${key}.jar"
}

ensure_cache_dir() { init_jar; mkdir -p "$CACHE_DIR"; chmod 700 "$CACHE_DIR"; }

cookie_val() {
  local name="$1"
  init_jar
  [ -f "$JAR" ] || return 1
  awk -v n="$name" '$0 !~ /^#/ && $6 == n { print $7; found=1 } END { exit !found }' "$JAR"
}

session_fresh() {
  init_jar
  [ -f "$JAR" ] || return 1
  local now; now=$(date +%s)
  awk -v n="sessionid" -v now="$now" '
    $0 !~ /^#/ && $6 == n {
      if ($5 == 0 || $5 > now + 30) { print "ok"; exit }
    }' "$JAR" | grep -q ok
}

do_login() {
  ensure_cache_dir
  ( umask 077; : > "$JAR" )
  local body code
  body=$(jq -n --arg u "$TUBEARCHIVIST_USERNAME" --arg p "$TUBEARCHIVIST_PASSWORD" \
    '{username:$u, password:$p}')
  code=$(curl -sS -o /dev/null -w "%{http_code}" \
    -c "$JAR" -b "$JAR" \
    -H "Content-Type: application/json" \
    -X POST -d "$body" \
    "$TA_API/user/login/")
  if [ "$code" != "204" ] && [ "$code" != "200" ]; then
    echo "ERROR: TubeArchivist login failed (HTTP $code)" >&2
    exit 1
  fi
}

ta_login() { session_fresh || do_login; }

ta_get() {
  local path="$1"
  ta_login
  curl -fsS -b "$JAR" "$TA_API$path"
}

ta_send() {
  local method="$1" path="$2" body="${3:-}"
  ta_login
  local csrf; csrf=$(cookie_val csrftoken) || { echo "ERROR: no csrftoken in jar" >&2; exit 1; }
  if [ -n "$body" ]; then
    curl -fsS -X "$method" -b "$JAR" -c "$JAR" \
      -H "Content-Type: application/json" \
      -H "X-CSRFToken: $csrf" \
      -H "Referer: $TA_BASE/" \
      -d "$body" \
      "$TA_API$path"
  else
    curl -fsS -X "$method" -b "$JAR" -c "$JAR" \
      -H "X-CSRFToken: $csrf" \
      -H "Referer: $TA_BASE/" \
      "$TA_API$path"
  fi
}

# Phase 1: resolve handle
TARGET_URL=$(normalize_target "$HANDLE")
log "resolving handle: $HANDLE -> $TARGET_URL"
RESOLVED=$(resolve_channel "$TARGET_URL" || true)
if [ -z "$RESOLVED" ] || [ "$(printf '%s' "$RESOLVED" | jq -r '.channel_id // empty')" = "" ]; then
  echo "ERROR: yt-dlp could not resolve '$HANDLE'. Check the handle/URL." >&2
  exit 1
fi
CHANNEL_ID=$(printf '%s' "$RESOLVED" | jq -r '.channel_id')
YT_CHANNEL_NAME=$(printf '%s' "$RESOLVED" | jq -r '.channel // empty')
log "resolved: channel_id=$CHANNEL_ID channel=$YT_CHANNEL_NAME"

if [ "$RESOLVE_ONLY" -eq 1 ]; then
  printf '%s\n' "$RESOLVED"
  exit 0
fi

# Phase 2: subscribe in TubeArchivist
log "subscribing in TubeArchivist"
SUB_BODY=$(jq -n --arg t "$CHANNEL_ID" '{data:[{channel_id:$t, channel_subscribed:true}]}')
ta_send POST /channel/ "$SUB_BODY" >/dev/null
log "subscribe queued"

# Phase 3: fetch top-N by view count from most recent K uploads.
# Non-flat extraction is needed for view_count, which is why JS_RUNTIME matters.
# We always hit the /videos tab so we get the recent-uploads order.
VIDEOS_URL="$TARGET_URL"
case "$VIDEOS_URL" in
  */videos) ;;
  */) VIDEOS_URL="${VIDEOS_URL}videos" ;;
  *)  VIDEOS_URL="${VIDEOS_URL}/videos" ;;
esac
log "fetching top $TOP by views from last $RECENT uploads ($VIDEOS_URL)"
RANKED=$(remote_ytdlp \
  --skip-download \
  --playlist-end "$RECENT" \
  -O '%(id)s|%(view_count)s|%(title)s' \
  "'$VIDEOS_URL'" 2>/dev/null \
  | awk -F'|' 'NF>=3 && $1 != "" && $2 != "NA" { printf "{\"id\":\"%s\",\"view_count\":%s,\"title\":", $1, $2; t=""; for (i=3;i<=NF;i++){ t = (i==3?$i:t"|"$i) } gsub(/\\/, "\\\\", t); gsub(/"/, "\\\"", t); printf "\"%s\"}\n", t }' \
  | jq -s --argjson top "$TOP" '
      sort_by(.view_count) | reverse | .[0:$top]
      | map({id, title, view_count})')
COUNT=$(printf '%s' "$RANKED" | jq 'length')
if [ "$COUNT" = "0" ] || [ -z "$COUNT" ]; then
  echo "ERROR: yt-dlp returned no rankable videos for $TARGET_URL" >&2
  exit 1
fi
log "ranked $COUNT videos"

# Phase 4: queue them in TubeArchivist
log "queueing $COUNT videos in TubeArchivist"
QUEUE_BODY=$(printf '%s' "$RANKED" | jq '{data: [.[] | {youtube_id: .id, status: "pending"}]}')
ta_send POST '/download/?autostart=true' "$QUEUE_BODY" >/dev/null
log "queue submitted"

# Phase 5: trigger the download_pending task
log "triggering download_pending task"
TASK_BODY='{"run":true}'
ta_send POST /task-name/download_pending/ "$TASK_BODY" >/dev/null || true

# Phase 6: wait for the first video file to land
log "waiting for first download under $MEDIA_ROOT/$CHANNEL_ID"
DEADLINE=$(( $(date +%s) + 600 ))
FIRST_FILE=""
until [ -n "$FIRST_FILE" ] || [ "$(date +%s)" -ge "$DEADLINE" ]; do
  FIRST_FILE=$(ssh -o BatchMode=yes "$SSH_TARGET" \
    "pct exec $LXC_ID -- bash -c 'ls -1 $MEDIA_ROOT/$CHANNEL_ID/*.mp4 2>/dev/null | head -1'" \
    || true)
  if [ -z "$FIRST_FILE" ]; then
    sleep 15
  fi
done
if [ -z "$FIRST_FILE" ]; then
  echo "ERROR: timed out after 10m waiting for first download under $MEDIA_ROOT/$CHANNEL_ID" >&2
  exit 1
fi
log "first file: $FIRST_FILE"

# Phase 7: trigger Jellyfin library scan
log "triggering Jellyfin library scan"
curl -fsS -X POST -H "$JF_AUTH" "$JF_API/Library/Refresh" -o /dev/null
# Give the scan a moment to register the new folder before we look for it.
SCAN_DEADLINE=$(( $(date +%s) + 300 ))

# Find the YouTube library id by name (case-insensitive contains "youtube").
log "locating YouTube library in Jellyfin"
YT_LIB_ID=$(curl -fsS -H "$JF_AUTH" "$JF_API/Library/VirtualFolders" \
  | jq -r '[.[] | select(.Name | ascii_downcase | contains("youtube"))][0].ItemId // empty')
if [ -z "$YT_LIB_ID" ]; then
  echo "ERROR: could not find a Jellyfin library containing 'YouTube' in its name" >&2
  exit 1
fi
log "youtube library id: $YT_LIB_ID"

# Phase 8: rename + lock the new channel folder
log "waiting for Jellyfin to index channel folder ($CHANNEL_ID)"
ITEM_ID=""
until [ -n "$ITEM_ID" ] || [ "$(date +%s)" -ge "$SCAN_DEADLINE" ]; do
  ITEM_ID=$(curl -fsS -H "$JF_AUTH" \
    "$JF_API/Items?Recursive=false&parentId=$YT_LIB_ID&Fields=Path,Name" \
    | jq -r --arg name "$CHANNEL_ID" \
        '[.Items[] | select(.Name == $name or ((.Path // "") | endswith("/" + $name)))][0].Id // empty')
  if [ -z "$ITEM_ID" ]; then
    sleep 15
  fi
done
if [ -z "$ITEM_ID" ]; then
  echo "ERROR: Jellyfin did not surface a folder named $CHANNEL_ID after scan" >&2
  exit 1
fi
log "jellyfin item id: $ITEM_ID"

USER_ID=$(curl -fsS -H "$JF_AUTH" "$JF_API/Users" \
  | jq -r '[.[] | select(.Policy.IsDisabled != true)][0].Id')
if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
  echo "ERROR: no usable Jellyfin user found" >&2
  exit 1
fi

log "renaming Jellyfin folder to: $FRIENDLY (and locking Name)"
FULL=$(curl -fsS -H "$JF_AUTH" "$JF_API/Users/$USER_ID/Items/$ITEM_ID")
PATCHED=$(printf '%s' "$FULL" | jq --arg n "$FRIENDLY" '
  .Name = $n
  | .LockedFields = ((.LockedFields // []) + ["Name"] | unique)
')
curl -fsS -X POST -H "$JF_AUTH" -H "Content-Type: application/json" \
  -d "$PATCHED" "$JF_API/Items/$ITEM_ID" -o /dev/null

log "done"
jq -n \
  --arg channel_id "$CHANNEL_ID" \
  --arg yt_name "$YT_CHANNEL_NAME" \
  --arg friendly "$FRIENDLY" \
  --arg first_file "$FIRST_FILE" \
  --arg jf_item "$ITEM_ID" \
  --argjson queued "$COUNT" \
  '{
     channel_id: $channel_id,
     youtube_name: $yt_name,
     jellyfin_name: $friendly,
     queued: $queued,
     first_file: $first_file,
     jellyfin_item_id: $jf_item
   }'
