#!/usr/bin/env bash
# PRD Update Script - Updates a story's status

PRD_FILE="ralph/prd.json"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <story-id> <status>"
    echo "Status options: pending, in_progress, complete, blocked"
    exit 1
fi

STORY_ID="$1"
NEW_STATUS="$2"

if [[ ! "$NEW_STATUS" =~ ^(pending|in_progress|complete|blocked)$ ]]; then
    echo "Error: Invalid status '$NEW_STATUS'"
    echo "Valid options: pending, in_progress, complete, blocked"
    exit 1
fi

STORY_EXISTS=$(jq --arg id "$STORY_ID" '.stories[] | select(.id == $id) | .id' "$PRD_FILE")
if [ -z "$STORY_EXISTS" ]; then
    echo "Error: Story '$STORY_ID' not found in PRD"
    exit 1
fi

CURRENT_STATUS=$(jq -r --arg id "$STORY_ID" '.stories[] | select(.id == $id) | .status' "$PRD_FILE")
echo "Updating story $STORY_ID: $CURRENT_STATUS -> $NEW_STATUS"

jq --arg id "$STORY_ID" --arg status "$NEW_STATUS" '
    .stories = [.stories[] | if .id == $id then .status = $status else . end] |
    .updated_at = (now | strftime("%Y-%m-%d"))
' "$PRD_FILE" > "${PRD_FILE}.tmp" && mv "${PRD_FILE}.tmp" "$PRD_FILE"

echo "Done!"
