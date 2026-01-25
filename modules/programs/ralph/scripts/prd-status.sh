#!/usr/bin/env bash
# PRD Status Script - Shows current progress

PRD_FILE="${1:-ralph/prd.json}"

if [ ! -f "$PRD_FILE" ]; then
    echo "Error: PRD file not found: $PRD_FILE"
    exit 1
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "PRD Status Report"
echo "========================================"

TOTAL=$(jq '.stories | length' "$PRD_FILE")
COMPLETE=$(jq '[.stories[] | select(.status == "complete")] | length' "$PRD_FILE")
IN_PROGRESS=$(jq '[.stories[] | select(.status == "in_progress")] | length' "$PRD_FILE")
PENDING=$(jq '[.stories[] | select(.status == "pending")] | length' "$PRD_FILE")
BLOCKED=$(jq '[.stories[] | select(.status == "blocked")] | length' "$PRD_FILE")

echo ""
echo "Summary:"
echo -e "  Total:       $TOTAL"
echo -e "  ${GREEN}Complete:    $COMPLETE${NC}"
echo -e "  ${YELLOW}In Progress: $IN_PROGRESS${NC}"
echo -e "  ${BLUE}Pending:     $PENDING${NC}"
echo -e "  ${RED}Blocked:     $BLOCKED${NC}"

if [ $TOTAL -gt 0 ]; then
    PERCENT=$((COMPLETE * 100 / TOTAL))
    BAR_WIDTH=40
    FILLED=$((PERCENT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))

    echo ""
    echo -n "Progress: ["
    printf "%${FILLED}s" | tr ' ' '#'
    printf "%${EMPTY}s" | tr ' ' '-'
    echo "] $PERCENT%"
fi

echo ""
echo "Stories by Phase:"
echo "----------------------------------------"

jq -r '.stories | group_by(.phase) | .[] |
    "Phase: \(.[0].phase)\n" +
    (. | map("  [\(.status | if . == "complete" then "✓" elif . == "in_progress" then "→" elif . == "blocked" then "✗" else " " end)] \(.id) - \(.title)") | join("\n"))' "$PRD_FILE"

echo ""
echo "----------------------------------------"
echo "Next Priority Story:"
echo "----------------------------------------"

NEXT=$(jq -r '.stories[] | select(.status == "pending") | "\(.id) - \(.title)\n  Phase: \(.phase)\n  Epic: \(.epic)\n  Complexity: \(.estimated_complexity)"' "$PRD_FILE" | head -4)

if [ -n "$NEXT" ]; then
    echo "$NEXT"
else
    echo "No pending stories!"
fi
