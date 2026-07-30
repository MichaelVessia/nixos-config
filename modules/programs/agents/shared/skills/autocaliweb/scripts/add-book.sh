#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
add-book.sh - copy a book file into AutoCaliWeb's ingest folder

usage:
  bash scripts/add-book.sh <file-or-url> [--name "Book.epub"] [--ingest-dir DIR] [--proxmox-host HOST] [--ctid ID] [--dry-run]

env:
  AUTOCALIWEB_INGEST_DIR  ingest path, usually /book-ingest in LXC 101
  AUTOCALIWEB_PROXMOX_HOST Proxmox SSH host, usually proxmox
  AUTOCALIWEB_CTID        AutoCaliWeb LXC id, usually 101
  AUTOCALIWEB_URL         optional UI URL, included in JSON output

options:
  --name NAME             destination filename, useful for URLs
  --ingest-dir DIR        override AUTOCALIWEB_INGEST_DIR
  --proxmox-host HOST     upload via ssh HOST pct exec CTID
  --ctid ID               Proxmox LXC id for remote upload
  --dry-run               validate and print planned copy without writing
  -h, --help              show this help
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

is_url() {
  case "$1" in
    http://*|https://*) return 0 ;;
    *) return 1 ;;
  esac
}

json_summary() {
  local status="$1" source="$2" destination="$3" dry_run="$4" mode="$5"
  jq -n \
    --arg status "$status" \
    --arg source "$source" \
    --arg destination "$destination" \
    --arg dryRun "$dry_run" \
    --arg mode "$mode" \
    --arg autocaliwebUrl "${AUTOCALIWEB_URL:-}" \
    '{
      status: $status,
      mode: $mode,
      source: $source,
      destination: $destination,
      dry_run: ($dryRun == "true"),
      autocaliweb_url: (if $autocaliwebUrl == "" then null else $autocaliwebUrl end)
    }'
}

quote() {
  printf '%q' "$1"
}

remote_shell() {
  local script="$1"
  ssh "$proxmox_host" "pct exec $ctid -- bash -lc $(quote "$script")"
}

source_arg=""
dest_name=""
ingest_dir="${AUTOCALIWEB_INGEST_DIR:-}"
proxmox_host="${AUTOCALIWEB_PROXMOX_HOST:-}"
ctid="${AUTOCALIWEB_CTID:-}"
dry_run=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      [ "$#" -ge 2 ] || die "--name requires a value"
      dest_name="$2"
      shift 2
      ;;
    --ingest-dir)
      [ "$#" -ge 2 ] || die "--ingest-dir requires a value"
      ingest_dir="$2"
      shift 2
      ;;
    --proxmox-host)
      [ "$#" -ge 2 ] || die "--proxmox-host requires a value"
      proxmox_host="$2"
      shift 2
      ;;
    --ctid)
      [ "$#" -ge 2 ] || die "--ctid requires a value"
      ctid="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      die "unknown option: $1"
      ;;
    *)
      if [ -n "$source_arg" ]; then
        die "multiple sources provided: $source_arg and $1"
      fi
      source_arg="$1"
      shift
      ;;
  esac
done

[ -n "$source_arg" ] || { usage >&2; exit 2; }
[ -n "$ingest_dir" ] || die "AUTOCALIWEB_INGEST_DIR not set and --ingest-dir not provided"

mode="local"
if [ -n "$proxmox_host" ] || [ -n "$ctid" ]; then
  [ -n "$proxmox_host" ] || die "AUTOCALIWEB_PROXMOX_HOST not set and --proxmox-host not provided"
  [ -n "$ctid" ] || die "AUTOCALIWEB_CTID not set and --ctid not provided"
  case "$ctid" in
    *[!0-9]*|'') die "invalid CTID: $ctid" ;;
  esac
  mode="proxmox-lxc"
fi

if [ "$mode" = "local" ]; then
  [ -d "$ingest_dir" ] || die "ingest directory does not exist: $ingest_dir"
  [ -w "$ingest_dir" ] || die "ingest directory is not writable: $ingest_dir"
else
  remote_ingest_dir=$(quote "$ingest_dir")
  remote_shell "[ -d $remote_ingest_dir ] && [ -w $remote_ingest_dir ]" \
    || die "remote ingest directory missing or not writable: $proxmox_host CT $ctid:$ingest_dir"
fi

tmpdir=""
cleanup() {
  if [ -n "$tmpdir" ] && [ -d "$tmpdir" ]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

source_path="$source_arg"
if is_url "$source_arg"; then
  tmpdir=$(mktemp -d)
  inferred_name="${source_arg%%\?*}"
  inferred_name="$(basename "$inferred_name")"
  if [ -z "$dest_name" ]; then
    [ -n "$inferred_name" ] && [ "$inferred_name" != "/" ] || die "URL source requires --name"
    dest_name="$inferred_name"
  fi
  source_path="$tmpdir/$dest_name"
  if [ "$dry_run" = false ]; then
    curl -fL --retry 3 --output "$source_path" "$source_arg"
  fi
else
  [ -f "$source_path" ] || die "source file does not exist: $source_path"
  [ -r "$source_path" ] || die "source file is not readable: $source_path"
  if [ -z "$dest_name" ]; then
    dest_name="$(basename "$source_path")"
  fi
fi

dest_name="$(basename "$dest_name")"
[ -n "$dest_name" ] && [ "$dest_name" != "." ] && [ "$dest_name" != "/" ] || die "invalid destination filename"

destination="$ingest_dir/$dest_name"
if [ "$mode" = "local" ]; then
  [ ! -e "$destination" ] || die "destination already exists: $destination"
else
  remote_destination=$(quote "$destination")
  remote_shell "[ ! -e $remote_destination ]" \
    || die "remote destination already exists: $proxmox_host CT $ctid:$destination"
fi

if [ "$dry_run" = true ]; then
  json_summary "planned" "$source_arg" "$destination" "true" "$mode"
  exit 0
fi

[ -f "$source_path" ] || die "download did not create source file: $source_path"
if [ "$mode" = "local" ]; then
  cp "$source_path" "$destination"
  chmod 0644 "$destination"
else
  remote_shell "cat > $remote_destination && chmod 0644 $remote_destination && { chown acw:acw $remote_destination 2>/dev/null || true; }" < "$source_path"
fi

json_summary "queued" "$source_arg" "$destination" "false" "$mode"
