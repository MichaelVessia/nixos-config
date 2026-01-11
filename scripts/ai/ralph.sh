#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ralph [max_iterations] [ralph_dir] [prompt]
# - max_iterations: default 10
# - ralph_dir: directory containing prd.json/progress.txt (default: .)
# - prompt: the prompt to use (default: built-in)

set -e

MAX_ITERATIONS=${1:-10}
RALPH_DIR=${2:-.}
PROMPT_ARG=${3:-}

PRD_FILE="$RALPH_DIR/prd.json"
PROGRESS_FILE="$RALPH_DIR/progress.txt"
ARCHIVE_DIR="$RALPH_DIR/archive"
LAST_BRANCH_FILE="$RALPH_DIR/.ralph-last-branch"

# Default prompt
DEFAULT_PROMPT='# Ralph Agent Instructions

## Your Task

1. Read `prd.json` in the ralph directory
2. Read `progress.txt` (check Codebase Patterns first)
3. Check you are on the correct branch
4. Pick highest priority story where `passes: false`
5. Implement that ONE story
6. Run typecheck and tests
7. Update AGENTS.md files with learnings
8. Commit: `feat: [ID] - [Title]`
9. Update prd.json: `passes: true`
10. Append learnings to progress.txt

## Stop Condition

If ALL stories pass, reply:
<promise>COMPLETE</promise>

Otherwise end normally.'

# Use provided prompt or default
if [ -n "$PROMPT_ARG" ]; then
  PROMPT="$PROMPT_ARG"
elif [ -f "$RALPH_DIR/prompt.md" ]; then
  PROMPT=$(cat "$RALPH_DIR/prompt.md")
else
  PROMPT="$DEFAULT_PROMPT"
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" >"$PROGRESS_FILE"
    echo "Started: $(date)" >>"$PROGRESS_FILE"
    echo "---" >>"$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" >"$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" >"$PROGRESS_FILE"
  echo "Started: $(date)" >>"$PROGRESS_FILE"
  echo "---" >>"$PROGRESS_FILE"
fi

echo "Starting Ralph - Max iterations: $MAX_ITERATIONS, Dir: $RALPH_DIR"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  TMPFILE=$(mktemp)
  claude -p "$PROMPT" --dangerously-skip-permissions 2>&1 | tee "$TMPFILE" || true

  if grep -q "<promise>COMPLETE</promise>" "$TMPFILE"; then
    rm -f "$TMPFILE"
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  rm -f "$TMPFILE"

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
