#!/usr/bin/env bash
# Stream filter for agent JSONL output (Claude, Codex, OpenCode-like events).

set -euo pipefail

BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

last_was_tool=false

while IFS= read -r line; do
  [ -z "$line" ] && continue

  if ! echo "$line" | jq . >/dev/null 2>&1; then
    echo "$line"
    last_was_tool=false
    continue
  fi

  event_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

  case "$event_type" in
  "text" | "message" | "assistant" | "output_text" | "output_text_delta" | "final")
    text=$(echo "$line" | jq -r '
      if .type == "text" then .part.text // .text // empty
      elif .type == "output_text" then .part.text // .text // empty
      elif .type == "output_text_delta" then .part.delta // .delta // empty
      elif .type == "final" then .part.text // .text // empty
      elif .type == "message" or .type == "assistant" then
        (
          .part.text // empty,
          .message.content[]? | select(.type == "text" or .type == "output_text") | .text // empty,
          .message.content[]? | select(.type == "output_text_delta") | .delta // empty,
          .part.content[]? | select(.type == "text" or .type == "output_text") | .text // empty,
          .part.content[]? | select(.type == "output_text_delta") | .delta // empty
        )
      else empty end
    ' 2>/dev/null)
    if [ -n "$text" ]; then
      $last_was_tool && echo ""
      printf "%s" "$text"
      last_was_tool=false
    fi
    ;;
  "tool_use")
    tool_name=$(echo "$line" | jq -r '.name // .part.tool // empty' 2>/dev/null)
    tool_detail=$(echo "$line" | jq -r '.part.state.title // empty' 2>/dev/null)
    if [ -z "$tool_detail" ]; then
      input=$(echo "$line" | jq -c '.input // .part.state.input // {}' 2>/dev/null)
      case "$tool_name" in
      Read | read)
        tool_detail=$(echo "$input" | jq -r '.file_path // .filePath // empty' 2>/dev/null)
        ;;
      Write | write)
        tool_detail=$(echo "$input" | jq -r '.file_path // .filePath // empty' 2>/dev/null)
        ;;
      Edit | edit)
        tool_detail=$(echo "$input" | jq -r '.file_path // .filePath // empty' 2>/dev/null)
        ;;
      Glob | glob)
        tool_detail=$(echo "$input" | jq -r '.pattern // empty' 2>/dev/null)
        ;;
      Grep | grep)
        tool_detail=$(echo "$input" | jq -r '.pattern // empty' 2>/dev/null)
        ;;
      Bash | bash)
        tool_detail=$(echo "$input" | jq -r '.description // .command // empty' 2>/dev/null)
        ;;
      Task | task)
        tool_detail=$(echo "$input" | jq -r '.description // empty' 2>/dev/null)
        ;;
      *)
        tool_detail=""
        ;;
      esac
    fi
    if [ -n "$tool_name" ]; then
      $last_was_tool || echo ""
      echo -e "${BLUE}> ${tool_name}${tool_detail:+: $tool_detail}${NC}"
      last_was_tool=true
    fi
    ;;
  "error")
    error_msg=$(echo "$line" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)
    echo -e "\n${RED}Error: $error_msg${NC}"
    last_was_tool=false
    ;;
  "result" | "step_finish")
    $last_was_tool || echo ""
    result=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
    [ -n "$result" ] && echo "$result"
    last_was_tool=false
    ;;
  *)
    :
    ;;
  esac
done

echo ""
