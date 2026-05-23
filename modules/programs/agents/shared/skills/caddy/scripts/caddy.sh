#!/usr/bin/env bash
# Caddy admin API wrapper.
# CADDY_URL is exported from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${CADDY_URL:?CADDY_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${CADDY_URL%/}"

cmd="${1:-help}"
shift || true

case "$cmd" in
  config)
    curl -fsS "$API/config/" | jq
    ;;

  routes)
    curl -fsS "$API/config/" | jq '
      .apps.http.servers
      | to_entries[]
      | {
          server: .key,
          listen: .value.listen,
          routes: [
            .value.routes[]? | {
              match: .match,
              upstreams: [
                .. | objects | select(.handler? == "reverse_proxy") | .upstreams[]?.dial
              ]
            }
          ]
        }
    '
    ;;

  upstreams)
    curl -fsS "$API/reverse_proxy/upstreams" | jq
    ;;

  pki-ca)
    curl -fsS "$API/pki/ca/local" | jq
    ;;

  reload)
    file="${1:?usage: reload <path-to-config.json>}"
    if [ ! -f "$file" ]; then
      echo "ERROR: config file not found: $file" >&2
      exit 1
    fi
    result=$(curl -fsS -X POST -H "Content-Type: application/json" \
      --data-binary "@${file}" "$API/load" -w '\n%{http_code}')
    body=$(echo "$result" | head -n -1)
    code=$(echo "$result" | tail -n 1)
    if [ "$code" = "200" ]; then
      echo "Reloaded config from: $file"
    else
      echo "ERROR: reload failed (HTTP $code)" >&2
      [ -n "$body" ] && echo "$body" >&2
      exit 1
    fi
    ;;

  help|--help|-h|"")
    cat <<EOF
caddy.sh — wrapper for the Caddy admin API

env required: CADDY_URL (from sops-nix; e.g. http://192.168.1.252:2019)

commands:
  config                       GET /config/ (full active config, jq pretty-printed)
  routes                       extract apps.http.servers.*.routes (matchers + upstreams)
  upstreams                    GET /reverse_proxy/upstreams (live pool + health)
  pki-ca                       GET /pki/ca/local (internal CA info)
  reload <config.json>         POST /load (replace active config) — destructive
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
