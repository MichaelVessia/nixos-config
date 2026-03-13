#!/usr/bin/env bash
# Stream Filter for Claude JSON output

BLUE='\033[0;34m'
NC='\033[0m'

while IFS= read -r line; do
    [ -z "$line" ] && continue

    type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

    case "$type" in
        "assistant")
            text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text // empty' 2>/dev/null)
            [ -n "$text" ] && echo "$text"
            ;;
        "tool_use")
            tool=$(echo "$line" | jq -r '.name // empty' 2>/dev/null)
            case "$tool" in
                "Read")
                    path=$(echo "$line" | jq -r '.input.file_path // empty' 2>/dev/null)
                    echo -e "${BLUE}> Read: ${path:0:80}${NC}"
                    ;;
                "Write")
                    path=$(echo "$line" | jq -r '.input.file_path // empty' 2>/dev/null)
                    echo -e "${BLUE}> Write: ${path:0:80}${NC}"
                    ;;
                "Edit")
                    path=$(echo "$line" | jq -r '.input.file_path // empty' 2>/dev/null)
                    echo -e "${BLUE}> Edit: ${path:0:80}${NC}"
                    ;;
                "Glob")
                    pattern=$(echo "$line" | jq -r '.input.pattern // empty' 2>/dev/null)
                    echo -e "${BLUE}> Glob: ${pattern:0:60}${NC}"
                    ;;
                "Grep")
                    pattern=$(echo "$line" | jq -r '.input.pattern // empty' 2>/dev/null)
                    echo -e "${BLUE}> Grep: ${pattern:0:60}${NC}"
                    ;;
                "Bash")
                    cmd=$(echo "$line" | jq -r '.input.command // empty' 2>/dev/null)
                    echo -e "${BLUE}> Bash: ${cmd:0:80}${NC}"
                    ;;
                "Task")
                    desc=$(echo "$line" | jq -r '.input.description // empty' 2>/dev/null)
                    echo -e "${BLUE}> Task: ${desc:0:60}${NC}"
                    ;;
                *)
                    [ -n "$tool" ] && echo -e "${BLUE}> $tool${NC}"
                    ;;
            esac
            ;;
        "result")
            result=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
            [ -n "$result" ] && echo "" && echo "$result"
            ;;
    esac
done
