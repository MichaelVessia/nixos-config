#!/usr/bin/env bash
# AdGuard Home API wrapper.
# Credentials come from the shell environment, populated by sops-nix
# (see modules/programs/shell.nix). No .env loading here.
set -euo pipefail

: "${ADGUARD_URL:?ADGUARD_URL not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${ADGUARD_USERNAME:?ADGUARD_USERNAME not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"
: "${ADGUARD_PASSWORD:?ADGUARD_PASSWORD not set. Export from sops-nix via modules/programs/shell.nix and open a fresh shell.}"

API="${ADGUARD_URL%/}/control"
AUTH="$ADGUARD_USERNAME:$ADGUARD_PASSWORD"

cmd="${1:-help}"
shift || true

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

case "$cmd" in
  status)
    curl -fsS -u "$AUTH" "$API/status" | jq '{version, running, protection_enabled, dns_addresses, dns_port, http_port, protection_disabled_duration}'
    ;;

  version)
    curl -fsS -u "$AUTH" "$API/status" | jq -r '.version'
    ;;

  stats)
    curl -fsS -u "$AUTH" "$API/stats" | jq '{
      num_dns_queries,
      num_blocked_filtering,
      num_replaced_safebrowsing,
      num_replaced_parental,
      num_replaced_safesearch,
      avg_processing_time,
      time_units,
      top_queried_domains: (.top_queried_domains[:10]),
      top_blocked_domains: (.top_blocked_domains[:10]),
      top_clients: (.top_clients[:10])
    }'
    ;;

  stats-info)
    curl -fsS -u "$AUTH" "$API/stats_info" | jq '.'
    ;;

  query-log)
    n="${1:-50}"
    curl -fsS -u "$AUTH" "$API/querylog?limit=${n}" | jq '[
      .data[] | {
        time,
        client,
        question: .question.name,
        type: .question.type,
        status,
        reason,
        elapsedMs,
        answer: ([.answer[]?.value] | join(", "))
      }
    ]'
    ;;

  query-log-search)
    query="${1:?usage: query-log-search <substring>}"
    curl -fsS -u "$AUTH" "$API/querylog?search=$(urlencode "$query")&limit=200" | jq '[
      .data[] | {
        time,
        client,
        question: .question.name,
        type: .question.type,
        status,
        reason,
        elapsedMs,
        answer: ([.answer[]?.value] | join(", "))
      }
    ]'
    ;;

  clients)
    curl -fsS -u "$AUTH" "$API/clients" | jq '{
      configured: [.clients[]? | {name, ids, tags, upstreams, filtering_enabled, use_global_settings, blocked_services}],
      auto_count: (.auto_clients | length),
      auto_sample: (.auto_clients[:10] | map({name, ip, source}))
    }'
    ;;

  clients-active)
    ip="${1:?usage: clients-active <ip>}"
    curl -fsS -u "$AUTH" "$API/clients/find?ip0=$(urlencode "$ip")" | jq '.'
    ;;

  filters)
    curl -fsS -u "$AUTH" "$API/filtering/status" | jq '{
      enabled,
      interval_hours: .interval,
      user_rules_count: (.user_rules | length),
      blocklists: [.filters[] | {id, name, enabled, rules_count, last_updated, url}],
      allowlists: [.whitelist_filters[]? | {id, name, enabled, rules_count, last_updated, url}]
    }'
    ;;

  rules)
    curl -fsS -u "$AUTH" "$API/filtering/status" | jq '.user_rules'
    ;;

  dns-config)
    curl -fsS -u "$AUTH" "$API/dns_info" | jq '.'
    ;;

  dhcp-status)
    curl -fsS -u "$AUTH" "$API/dhcp/status" | jq '{
      enabled,
      interface_name,
      v4: .v4,
      v6: .v6,
      lease_count: (.leases | length),
      static_lease_count: (.static_leases | length),
      leases: .leases,
      static_leases: .static_leases
    }'
    ;;

  protection-toggle)
    state="${1:?usage: protection-toggle <on|off>}"
    case "$state" in
      on)  enabled="true" ;;
      off) enabled="false" ;;
      *)   echo "ERROR: protection-toggle takes on|off, got: $state" >&2; exit 2 ;;
    esac
    body=$(jq -n --argjson e "$enabled" '{enabled: $e, duration: 0}')
    curl -fsS -X POST -u "$AUTH" -H "Content-Type: application/json" -d "$body" "$API/protection" >/dev/null
    curl -fsS -u "$AUTH" "$API/status" | jq '{protection_enabled, protection_disabled_duration}'
    ;;

  help|--help|-h|"")
    cat <<EOF
adguard.sh — wrapper for AdGuard Home HTTP API

env required: ADGUARD_URL, ADGUARD_USERNAME, ADGUARD_PASSWORD (from sops-nix)

commands:
  status                        GET /control/status
  version                       version string only
  stats                         24h counters + top domains/clients
  stats-info                    stats retention interval
  query-log [n]                 last n querylog entries (default 50)
  query-log-search <substr>     search querylog (limit 200)
  clients                       configured + auto-detected clients
  clients-active <ip>           lookup one client by IP
  filters                       blocklists, allowlists, custom rules count
  rules                         only the custom user_rules
  dns-config                    full DNS server config
  dhcp-status                   DHCP server status (if enabled)
  protection-toggle <on|off>    MUTATION — confirm first
EOF
    ;;

  *)
    echo "unknown command: $cmd" >&2
    echo "run: bash $(basename "$0") help" >&2
    exit 2
    ;;
esac
