#!/usr/bin/env bash
# Local tailscale CLI wrapper. Read-only.
# No env/secrets — uses whichever tailnet the local tailscaled is logged in to.
set -euo pipefail

command -v tailscale >/dev/null 2>&1 || {
  echo "ERROR: tailscale CLI not found on PATH" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq not found on PATH" >&2
  exit 1
}

# Bail early if the daemon is not authenticated.
require_logged_in() {
  local state
  state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Unknown"')
  case "$state" in
    Running) : ;;
    NeedsLogin|NoState|Stopped|Unknown)
      echo "ERROR: tailscale not logged in (BackendState=$state). Run 'tailscale up' interactively." >&2
      exit 1
      ;;
  esac
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  status)
    require_logged_in
    tailscale status --json | jq '{
      self: {
        hostname: .Self.HostName,
        dnsName: .Self.DNSName,
        ip: (.Self.TailscaleIPs[0] // null),
        online: .Self.Online,
        magicDNSSuffix: .MagicDNSSuffix,
        backendState: .BackendState
      },
      peers: (.Peer // {} | to_entries | map({
        hostname: .value.HostName,
        ip: (.value.TailscaleIPs[0] // null),
        online: .value.Online,
        exitNode: .value.ExitNode,
        exitNodeOption: .value.ExitNodeOption
      }))
    }'
    ;;

  peers)
    require_logged_in
    tailscale status --json | jq -r '
      ["HOSTNAME","IP","OS","ONLINE"],
      ( .Peer // {} | to_entries | sort_by(.value.HostName) | .[] |
        [ .value.HostName,
          (.value.TailscaleIPs[0] // "-"),
          (.value.OS // "-"),
          (if .value.Online then "yes" else "no" end)
        ] )
      | @tsv' | column -t -s $'\t'
    ;;

  exit-nodes)
    require_logged_in
    tailscale status --json | jq -r '
      ["HOSTNAME","IP","ONLINE","CURRENT"],
      ( .Peer // {} | to_entries | map(.value) | map(select(.ExitNodeOption == true)) |
        sort_by(.HostName) | .[] |
        [ .HostName,
          (.TailscaleIPs[0] // "-"),
          (if .Online then "yes" else "no" end),
          (if .ExitNode then "yes" else "no" end)
        ] )
      | @tsv' | column -t -s $'\t'
    ;;

  current-exit-node)
    require_logged_in
    tailscale status --json | jq '
      (.Peer // {} | to_entries | map(.value) | map(select(.ExitNode == true)) | .[0]) as $en |
      if $en == null then
        {usingExitNode: false}
      else
        {
          usingExitNode: true,
          hostname: $en.HostName,
          ip: ($en.TailscaleIPs[0] // null),
          online: $en.Online
        }
      end'
    ;;

  dns)
    require_logged_in
    tailscale dns status
    ;;

  ip)
    require_logged_in
    v4=$(tailscale ip -4 2>/dev/null || true)
    v6=$(tailscale ip -6 2>/dev/null || true)
    jq -n --arg v4 "$v4" --arg v6 "$v6" '{ipv4: $v4, ipv6: $v6}'
    ;;

  whois)
    target="${1:?usage: whois <ip-or-host>}"
    tailscale whois --json "$target"
    ;;

  ping)
    target="${1:?usage: ping <host>}"
    tailscale ping --c 3 "$target"
    ;;

  help|--help|-h|"")
    cat <<EOF
tailscale.sh — local tailscale CLI wrapper (read-only)

env required: none (uses local tailscaled session)

commands:
  status                 compact JSON: self + per-peer hostname/ip/online/exit flags
  peers                  table of all peers (hostname, IP, OS, online)
  exit-nodes             peers advertising as exit nodes
  current-exit-node      which peer (if any) we're routing through
  dns                    tailscale dns status (MagicDNS state)
  ip                     this machine's IPv4 and IPv6 tailnet addresses
  whois <ip-or-host>     identify a tailnet IP (JSON)
  ping <host>            tailscale ping --c 3 <host>
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
