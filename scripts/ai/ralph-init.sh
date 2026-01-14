#!/bin/bash
# ralph-init: Scaffold a Ralph autonomous coding agent setup in the current directory
set -e

RALPH_DIR="ralph"

if [ -d "$RALPH_DIR" ]; then
  echo "Error: ralph/ directory already exists"
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

echo "Creating Ralph scaffolding..."

mkdir -p "$RALPH_DIR/scripts"
mkdir -p ".ralph"

# Add .ralph/ to git excludes (local, doesn't modify .gitignore)
GIT_DIR=$(git rev-parse --git-dir)
if ! grep -q "^\.ralph/$" "$GIT_DIR/info/exclude" 2>/dev/null; then
  echo ".ralph/" >> "$GIT_DIR/info/exclude"
fi

# ralph.sh - main loop script
cat > "$RALPH_DIR/ralph.sh" << 'RALPH_SH'
#!/bin/bash

# Ralph Loop - Long-running AI coding agent orchestrator
#
# Usage: ./ralph/ralph.sh [--model MODEL] [--ci-model MODEL] [max_iterations]
#
# Options:
#   --model MODEL     Claude model for story work (sonnet, opus, haiku). Default: opus
#   --ci-model MODEL  Claude model for CI error fixing. Default: sonnet
#
# This script runs Claude Code in a loop, having it work through
# a PRD of user stories until all are complete or max iterations reached.
#
# COMMITS ARE HANDLED BY THIS SCRIPT, NOT THE AGENT.
# Each completed story = one atomic commit for easy rollback.

set -e

# Parse arguments
MODEL="opus"
CI_MODEL="sonnet"
MAX_ITERATIONS=10
MODEL_EXPLICIT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --model)
      MODEL="$2"
      MODEL_EXPLICIT=true
      shift 2
      ;;
    --ci-model)
      CI_MODEL="$2"
      shift 2
      ;;
    *)
      MAX_ITERATIONS="$1"
      shift
      ;;
  esac
done

# Configuration
RALPH_DIR="ralph"
PRD_FILE="$RALPH_DIR/prd.json"
PROGRESS_FILE="$RALPH_DIR/progress.txt"
PROMPT_FILE="$RALPH_DIR/RALPH_PROMPT.md"
COMPLETE_MARKER="<promise>COMPLETE</promise>"
OUTPUT_DIR=".ralph"
AGENT_CMD_BASE="claude --dangerously-skip-permissions --verbose"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory for logs
mkdir -p "$OUTPUT_DIR"

# Logging function
log() {
  local level=$1
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  case $level in
  "INFO") echo -e "${BLUE}[$timestamp]${NC} $message" ;;
  "SUCCESS") echo -e "${GREEN}[$timestamp]${NC} $message" ;;
  "WARN") echo -e "${YELLOW}[$timestamp]${NC} $message" ;;
  "ERROR") echo -e "${RED}[$timestamp]${NC} $message" ;;
  esac

  echo "[$timestamp] [$level] $message" >>"$OUTPUT_DIR/ralph.log"
}

# Check prerequisites
check_prerequisites() {
  log "INFO" "Checking prerequisites..."

  if ! command -v claude &>/dev/null; then
    log "ERROR" "Claude Code (claude) is not installed or not in PATH"
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    log "ERROR" "jq is not installed"
    exit 1
  fi

  if [ ! -f "$PRD_FILE" ]; then
    log "ERROR" "PRD file not found: $PRD_FILE"
    exit 1
  fi

  if [ ! -f "$PROMPT_FILE" ]; then
    log "ERROR" "Prompt file not found: $PROMPT_FILE"
    exit 1
  fi

  # Check if we're in a git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log "ERROR" "Not in a git repository"
    exit 1
  fi

  # Create progress file if it doesn't exist
  if [ ! -f "$PROGRESS_FILE" ]; then
    echo "# Progress Log" >"$PROGRESS_FILE"
    echo "# This file tracks progress across Ralph loop iterations" >>"$PROGRESS_FILE"
    echo "" >>"$PROGRESS_FILE"
  fi

  log "SUCCESS" "Prerequisites check passed"
}

# Get the current story being worked on (first in_progress or first pending in array order)
get_current_story() {
  local story=$(jq -r '[.stories[] | select(.status == "in_progress")] | .[0] // empty' "$PRD_FILE")

  if [ -z "$story" ]; then
    story=$(jq -r '[.stories[] | select(.status == "pending")] | .[0] // empty' "$PRD_FILE")
  fi

  echo "$story"
}

# Get story ID from story JSON
get_story_id() {
  echo "$1" | jq -r '.id'
}

# Get story title from story JSON
get_story_title() {
  echo "$1" | jq -r '.title'
}

# Get story phase from story JSON
get_story_phase() {
  echo "$1" | jq -r '.phase'
}

# Count incomplete stories in PRD
count_incomplete_stories() {
  jq '[.stories[] | select(.status != "complete")] | length' "$PRD_FILE"
}

# Get summary of PRD status
get_prd_status() {
  local total=$(jq '.stories | length' "$PRD_FILE")
  local complete=$(jq '[.stories[] | select(.status == "complete")] | length' "$PRD_FILE")
  local in_progress=$(jq '[.stories[] | select(.status == "in_progress")] | length' "$PRD_FILE")
  local pending=$(jq '[.stories[] | select(.status == "pending")] | length' "$PRD_FILE")

  echo "Total: $total | Complete: $complete | In Progress: $in_progress | Pending: $pending"
}

# Check if there are uncommitted changes
has_changes() {
  ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]
}

# Run CI checks
run_ci_checks() {
  log "INFO" "Running CI checks..."

  local ci_output
  ci_output=$(./$RALPH_DIR/scripts/ci-check.sh 2>&1)
  local ci_status=$?

  echo "$ci_output" | tee -a "$OUTPUT_DIR/ci.log"

  if [ $ci_status -ne 0 ]; then
    log "ERROR" "CI checks failed"
    local truncated_output
    local total_lines=$(echo "$ci_output" | wc -l)
    if [ "$total_lines" -gt 200 ]; then
      truncated_output=$(echo "$ci_output" | head -50)
      truncated_output="$truncated_output"$'\n\n... (truncated '$((total_lines - 150))' lines) ...\n\n'
      truncated_output="$truncated_output$(echo "$ci_output" | tail -100)"
    else
      truncated_output="$ci_output"
    fi
    echo "The previous iteration failed CI checks. Please fix these errors:" >"$OUTPUT_DIR/ci_errors.txt"
    echo "" >>"$OUTPUT_DIR/ci_errors.txt"
    echo '```' >>"$OUTPUT_DIR/ci_errors.txt"
    echo "$truncated_output" >>"$OUTPUT_DIR/ci_errors.txt"
    echo '```' >>"$OUTPUT_DIR/ci_errors.txt"
    return 1
  fi

  : >"$OUTPUT_DIR/ci_errors.txt"
  log "SUCCESS" "CI checks passed"
  return 0
}

# Commit changes for a story
commit_story() {
  local story_id="$1"
  local story_title="$2"
  local story_phase="$3"
  local iteration="$4"

  log "INFO" "Committing changes for story $story_id..."

  git add -A

  if git diff --cached --quiet; then
    log "WARN" "No changes to commit"
    return 0
  fi

  local commit_msg="feat($story_phase): $story_title

Story: $story_id
Ralph-Iteration: $iteration

Automated commit by Ralph loop.
To rollback this story: git revert HEAD"

  if git commit -m "$commit_msg"; then
    log "SUCCESS" "Committed: $story_id - $story_title"
    return 0
  else
    log "ERROR" "Commit failed"
    return 1
  fi
}

# Rollback uncommitted changes
rollback_changes() {
  log "WARN" "Rolling back uncommitted changes..."
  git checkout -- .
  git clean -fd
}

# Update story status in PRD
update_story_status() {
  local story_id="$1"
  local new_status="$2"

  jq --arg id "$story_id" --arg status "$new_status" \
    '(.stories[] | select(.id == $id)).status = $status' \
    "$PRD_FILE" >"${PRD_FILE}.tmp" && mv "${PRD_FILE}.tmp" "$PRD_FILE"
}

# Build the prompt for the agent
build_prompt() {
  local iteration=$1
  local story=$2

  local technology=$(jq '.technology' "$PRD_FILE")
  local reference_repos=$(jq '.reference_repos' "$PRD_FILE")
  local specs_dir=$(jq -r '.specs_dir // "specs/"' "$PRD_FILE")
  local progress_content=$(cat "$PROGRESS_FILE")
  local prompt_template=$(cat "$PROMPT_FILE")
  local ci_errors=""
  if [ -f "$OUTPUT_DIR/ci_errors.txt" ]; then
    ci_errors=$(cat "$OUTPUT_DIR/ci_errors.txt")
  fi

  if [ -z "$ci_errors" ]; then
    ci_errors="No errors from previous iteration."
  fi

  local story_specs=$(echo "$story" | jq -r '.specs // empty')
  local specs_list=""

  if [ -n "$story_specs" ] && [ "$story_specs" != "null" ]; then
    specs_list="**Required for this story:**
$(echo "$story" | jq -r '.specs[]' 2>/dev/null | while read spec; do
      echo "- \`${specs_dir}${spec}\`"
    done)

"
  fi

  specs_list="${specs_list}**All available specs in \`${specs_dir}\`:**
$(jq -r '.available_specs[]' "$PRD_FILE" 2>/dev/null | while read spec; do
    echo "- \`${specs_dir}${spec}\`"
  done)"

  local prompt="$prompt_template"
  prompt="${prompt//\{\{ITERATION\}\}/$iteration}"
  prompt="${prompt//\{\{MAX_ITERATIONS\}\}/$MAX_ITERATIONS}"
  prompt="${prompt//\{\{CURRENT_STORY\}\}/$story}"
  prompt="${prompt//\{\{TECHNOLOGY\}\}/$technology}"
  prompt="${prompt//\{\{REFERENCE_REPOS\}\}/$reference_repos}"
  prompt="${prompt//\{\{SPECS\}\}/$specs_list}"
  prompt="${prompt//\{\{PROGRESS_CONTENT\}\}/$progress_content}"
  prompt="${prompt//\{\{CI_ERRORS\}\}/$ci_errors}"

  echo "$prompt"
}

# Run a single iteration of the agent
run_iteration() {
  local iteration=$1
  local output_file="$OUTPUT_DIR/iteration_${iteration}_output.txt"

  local story=$(get_current_story)
  if [ -z "$story" ] || [ "$story" = "null" ]; then
    log "SUCCESS" "No more stories to process"
    return 0
  fi

  local story_id=$(get_story_id "$story")
  local story_title=$(get_story_title "$story")
  local story_phase=$(get_story_phase "$story")

  log "INFO" "Starting iteration $iteration of $MAX_ITERATIONS"
  log "INFO" "Story: $story_id - $story_title"
  log "INFO" "PRD Status: $(get_prd_status)"

  update_story_status "$story_id" "in_progress"

  local prompt=$(build_prompt "$iteration" "$story")

  local prompt_file="$OUTPUT_DIR/iteration_${iteration}_prompt.md"
  echo "$prompt" >"$prompt_file"

  local current_model="$MODEL"
  if [ "$MODEL_EXPLICIT" = false ] && [ -f "$OUTPUT_DIR/ci_errors.txt" ] && [ -s "$OUTPUT_DIR/ci_errors.txt" ]; then
    current_model="$CI_MODEL"
    log "INFO" "Using CI model ($CI_MODEL) for error fixing"
  fi
  local agent_cmd="$AGENT_CMD_BASE --model $current_model"

  log "INFO" "Running Claude Code agent (model: $current_model)..."
  echo ""

  if cat "$prompt_file" | $agent_cmd --print --output-format stream-json 2>&1 | tee "$output_file" | ./$RALPH_DIR/scripts/stream-filter.sh; then
    echo ""
    log "SUCCESS" "Agent completed iteration $iteration"
  else
    echo ""
    log "WARN" "Agent exited with non-zero status"
  fi

  if grep -q "STORY_COMPLETE" "$output_file"; then
    log "INFO" "Agent signaled story completion"

    if run_ci_checks; then
      update_story_status "$story_id" "complete"

      echo "" >>"$PROGRESS_FILE"
      echo "## Iteration $iteration - $(date '+%Y-%m-%d %H:%M')" >>"$PROGRESS_FILE"
      echo "**Story**: $story_id - $story_title" >>"$PROGRESS_FILE"
      echo "**Status**: complete" >>"$PROGRESS_FILE"
      echo "---" >>"$PROGRESS_FILE"

      if commit_story "$story_id" "$story_title" "$story_phase" "$iteration"; then
        log "SUCCESS" "Story $story_id completed and committed"
      else
        log "ERROR" "Failed to commit story $story_id"
        rollback_changes
        update_story_status "$story_id" "pending"
        return 1
      fi
    else
      log "WARN" "CI checks failed for story $story_id - keeping changes for next iteration to fix"
    fi
  else
    log "WARN" "Agent did not complete the story"
  fi

  if grep -q "$COMPLETE_MARKER" "$output_file"; then
    log "SUCCESS" "Agent signaled ALL COMPLETE"
    return 0
  fi

  return 1
}

# Main loop
main() {
  log "INFO" "=========================================="
  log "INFO" "Starting Ralph Loop"
  log "INFO" "Model: $MODEL (CI fixes: $CI_MODEL)"
  log "INFO" "Max iterations: $MAX_ITERATIONS"
  log "INFO" "PRD file: $PRD_FILE"
  log "INFO" "=========================================="

  check_prerequisites

  local start_time=$(date +%s)
  local iteration=1
  local completed=false

  while [ $iteration -le $MAX_ITERATIONS ]; do
    log "INFO" "------------------------------------------"
    log "INFO" "ITERATION $iteration / $MAX_ITERATIONS"
    log "INFO" "------------------------------------------"

    local incomplete=$(count_incomplete_stories)
    if [ "$incomplete" -eq 0 ]; then
      log "SUCCESS" "All PRD stories are complete!"
      completed=true
      break
    fi

    if run_iteration $iteration; then
      incomplete=$(count_incomplete_stories)
      if [ "$incomplete" -eq 0 ]; then
        log "SUCCESS" "All PRD stories are complete!"
        completed=true
        break
      fi
    fi

    sleep 2

    ((iteration++))
  done

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  log "INFO" "=========================================="
  log "INFO" "Ralph Loop Complete"
  log "INFO" "Total iterations: $((iteration))"
  log "INFO" "Duration: ${duration}s"
  log "INFO" "Final PRD Status: $(get_prd_status)"

  if [ "$completed" = true ]; then
    log "SUCCESS" "All work completed successfully!"
  else
    log "WARN" "Max iterations reached. Some work may remain."
  fi
  log "INFO" "=========================================="

  log "INFO" "Recent Ralph commits:"
  git log --oneline -10 --grep="Ralph-Iteration" || true

  if [ "$completed" = true ]; then
    exit 0
  else
    exit 1
  fi
}

main
RALPH_SH

# RALPH_PROMPT.md - prompt template
cat > "$RALPH_DIR/RALPH_PROMPT.md" << 'RALPH_PROMPT'
# Ralph Loop Agent Instructions

You are an autonomous coding agent. You are running as part of an automated loop
(iteration {{ITERATION}} of {{MAX_ITERATIONS}}).

## Your Mission

Implement the user story below. Complete it fully, ensure all checks pass, and
signal completion.

## Critical Rules

1. **ONE STORY ONLY**: Implement only the story provided below. Do NOT look for
   other stories.
2. **DO NOT COMMIT**: The Ralph script handles all git commits. Just write code
   and tests.
3. **DO NOT UPDATE PRD**: The Ralph script handles PRD status updates.
4. **KEEP CI GREEN**: Your code MUST pass all checks. Run the CI check command
   before signaling completion.
5. **SIGNAL COMPLETION**: When done with a story, output `STORY_COMPLETE` on its
   own line.

## Current Story

```json
{{CURRENT_STORY}}
```

## Technology Stack

```json
{{TECHNOLOGY}}
```

## Reference Repositories

Use these local paths to find patterns and best practices:

```json
{{REFERENCE_REPOS}}
```

## Specifications

{{SPECS}}

## Workflow

1. **Read** the required specs (if any) and browse others as needed
2. **Research** existing patterns in the codebase
3. **Implement** the story following the acceptance criteria
4. **Write tests** if the story requires new functionality
5. **Verify** - run the CI checks
6. **Signal** - if all checks pass, output `STORY_COMPLETE`

## Signaling Completion

When you have finished implementing a story and all checks pass:

```
STORY_COMPLETE
```

The Ralph script will then:

- Run CI checks
- Commit your changes with a deterministic message
- Update the PRD status
- Update the progress log

## Progress Log

```
{{PROGRESS_CONTENT}}
```

## Previous Iteration Errors

{{CI_ERRORS}}

## Important Reminders

- Read the relevant specs listed above for this story
- Read CLAUDE.md for project conventions and commands
- Follow existing patterns in the codebase
- DO NOT run git commands - the script handles commits
- DO NOT modify prd.json - the script handles status updates
- If blocked, output `STORY_BLOCKED: <reason>` and the script will handle it

## Begin

Implement the story above. When done and checks pass, output `STORY_COMPLETE`.
RALPH_PROMPT

# HOW_TO_RALPH.md
cat > "$RALPH_DIR/HOW_TO_RALPH.md" << 'HOW_TO_RALPH'
# How to Ralph

Quick guide to running autonomous coding tasks with Ralph.

## Prerequisites

- Claude Code CLI installed (`claude` command available)
- `jq` installed for JSON parsing
- Stories defined in `ralph/prd.json`

## Quick Start

```bash
# 1. Check what's in the queue
./ralph/scripts/prd-status.sh

# 2. Start the loop
./ralph/ralph.sh
```

That's it. Ralph picks the next pending story and starts working.

## Commands

| Command                                       | Description                         |
| --------------------------------------------- | ----------------------------------- |
| `./ralph/ralph.sh`                            | Run loop (default 10 iterations)    |
| `./ralph/ralph.sh 50`                         | Run loop with custom max iterations |
| `./ralph/scripts/prd-status.sh`               | Show PRD progress and next story    |
| `./ralph/scripts/prd-update.sh <id> <status>` | Manually update story status        |
| `./ralph/scripts/ci-check.sh`                 | Run CI checks manually              |

## Monitoring

```bash
# Watch progress in real-time
tail -f ralph/progress.txt

# Check PRD status
./ralph/scripts/prd-status.sh

# View agent output for iteration N
cat .ralph/iteration_N_output.txt
```

## Running Overnight

```bash
# Run in background with logging
nohup ./ralph/ralph.sh 100 > ralph-output.log 2>&1 &

# Check if still running
ps aux | grep ralph

# Stop if needed
pkill -f ralph.sh
```

## Story Lifecycle

```
pending → in_progress → complete
                     ↘ blocked (if stuck)
```

Ralph automatically:

1. Picks first pending story
2. Marks it `in_progress`
3. Runs Claude Code with the story prompt
4. Runs CI checks when Claude signals `STORY_COMPLETE`
5. Commits if CI passes, marks `complete`
6. Moves to next story

## Rollback

Each story = one atomic commit. Rollback is easy:

```bash
# See Ralph commits
git log --oneline --grep="Ralph-Iteration"

# Undo last story
git revert HEAD

# Undo specific story
git log --oneline --grep="Story: 1.2.0" | head -1 | cut -d' ' -f1 | xargs git revert

# Reset story status after rollback
./ralph/scripts/prd-update.sh 1.2.0 pending
```

## Adding Stories

Edit `ralph/prd.json` directly:

```json
{
  "id": "2.1.0",
  "phase": "Feature",
  "epic": "New Feature",
  "title": "Implement the thing",
  "description": "Detailed description of what to build",
  "acceptance_criteria": ["Criterion 1", "Criterion 2"],
  "specs": ["RELEVANT_SPEC.md"],
  "status": "pending",
  "estimated_complexity": "medium"
}
```

ID format: `phase.epic.story` (e.g., 1.2.3 = phase 1, epic 2, story 3)

Complexity: `small`, `medium`, `large`

## Troubleshooting

**Agent gets stuck:**

```bash
./ralph/scripts/prd-update.sh <id> blocked
# Add note to ralph/progress.txt explaining why
# Restart loop - it will skip blocked stories
```

**CI keeps failing:**

```bash
# Check what's failing
./ralph/scripts/ci-check.sh

# Fix manually, then restart
./ralph/ralph.sh
```

**Context window issues:**

- Break large stories into smaller ones
- Keep acceptance criteria focused

## Files

| File              | Purpose                            |
| ----------------- | ---------------------------------- |
| `prd.json`        | Stories and status                 |
| `progress.txt`    | Log of completed work              |
| `RALPH_PROMPT.md` | Prompt template sent to agent      |
| `.ralph/`         | Logs and debug output (gitignored) |
HOW_TO_RALPH

# prd.json - empty template
cat > "$RALPH_DIR/prd.json" << 'PRD_JSON'
{
  "project": "PROJECT_NAME",
  "description": "Project description",
  "updated_at": "2025-01-01",
  "technology": {
    "language": "TypeScript",
    "framework": "Your framework",
    "testing": "Your test framework"
  },
  "reference_repos": [],
  "specs_dir": "specs/",
  "available_specs": [],
  "stories": [
    {
      "id": "1.1.0",
      "phase": "Setup",
      "epic": "Initial Setup",
      "title": "Example story",
      "description": "Description of what needs to be done",
      "acceptance_criteria": [
        "First criterion",
        "Second criterion"
      ],
      "specs": [],
      "status": "pending",
      "estimated_complexity": "small"
    }
  ]
}
PRD_JSON

# progress.txt
cat > "$RALPH_DIR/progress.txt" << 'PROGRESS'
# Progress Log
# This file tracks progress across Ralph loop iterations

PROGRESS

# scripts/ci-check.sh
cat > "$RALPH_DIR/scripts/ci-check.sh" << 'CI_CHECK'
#!/bin/bash
# CI Check Script for Ralph Loop
# Customize this for your project's CI commands

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILED=0

echo "========================================"
echo "Running CI Checks"
echo "========================================"

# TODO: Customize these commands for your project
# Examples:
#   npm run typecheck
#   npm run lint
#   npm test
#   cargo check && cargo test
#   go build ./... && go test ./...

echo -e "\n${YELLOW}[1/2] Running quality checks...${NC}"
# if npm run check; then
#     echo -e "${GREEN}Quality checks passed!${NC}"
# else
#     echo -e "${RED}Quality checks failed!${NC}"
#     FAILED=1
# fi
echo -e "${YELLOW}TODO: Add your quality check commands${NC}"

echo -e "\n${YELLOW}[2/2] Running tests...${NC}"
# if npm test; then
#     echo -e "${GREEN}Tests passed!${NC}"
# else
#     echo -e "${RED}Tests failed!${NC}"
#     FAILED=1
# fi
echo -e "${YELLOW}TODO: Add your test commands${NC}"

echo ""
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All CI checks passed!${NC}"
    exit 0
else
    echo -e "${RED}CI checks failed!${NC}"
    exit 1
fi
CI_CHECK

# scripts/prd-status.sh
cat > "$RALPH_DIR/scripts/prd-status.sh" << 'PRD_STATUS'
#!/bin/bash
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
PRD_STATUS

# scripts/prd-update.sh
cat > "$RALPH_DIR/scripts/prd-update.sh" << 'PRD_UPDATE'
#!/bin/bash
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
PRD_UPDATE

# scripts/stream-filter.sh
cat > "$RALPH_DIR/scripts/stream-filter.sh" << 'STREAM_FILTER'
#!/bin/bash
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
STREAM_FILTER

# Make scripts executable
chmod +x "$RALPH_DIR/ralph.sh"
chmod +x "$RALPH_DIR/scripts/ci-check.sh"
chmod +x "$RALPH_DIR/scripts/prd-status.sh"
chmod +x "$RALPH_DIR/scripts/prd-update.sh"
chmod +x "$RALPH_DIR/scripts/stream-filter.sh"

echo ""
echo "Ralph scaffolding created!"
echo ""
echo "Next steps:"
echo "  1. Edit ralph/prd.json with your stories"
echo "  2. Edit ralph/scripts/ci-check.sh with your CI commands"
echo "  3. Optionally customize ralph/RALPH_PROMPT.md"
echo "  4. Run ./ralph/scripts/prd-status.sh to see status"
echo "  5. Run ./ralph/ralph.sh to start the loop"
