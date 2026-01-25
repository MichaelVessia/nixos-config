#!/usr/bin/env bash

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
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

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
  local story
  story=$(jq -r '[.stories[] | select(.status == "in_progress")] | .[0] // empty' "$PRD_FILE")

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
  local total complete in_progress pending
  total=$(jq '.stories | length' "$PRD_FILE")
  complete=$(jq '[.stories[] | select(.status == "complete")] | length' "$PRD_FILE")
  in_progress=$(jq '[.stories[] | select(.status == "in_progress")] | length' "$PRD_FILE")
  pending=$(jq '[.stories[] | select(.status == "pending")] | length' "$PRD_FILE")

  echo "Total: $total | Complete: $complete | In Progress: $in_progress | Pending: $pending"
}

# Check if there are uncommitted changes
has_changes() {
  ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]
}

# Run CI checks
run_ci_checks() {
  log "INFO" "Running CI checks..."

  local ci_output ci_status
  ci_output=$(./$RALPH_DIR/scripts/ci-check.sh 2>&1)
  ci_status=$?

  echo "$ci_output" | tee -a "$OUTPUT_DIR/ci.log"

  if [ $ci_status -ne 0 ]; then
    log "ERROR" "CI checks failed"
    local truncated_output total_lines
    total_lines=$(echo "$ci_output" | wc -l)
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

  local technology reference_repos specs_dir progress_content prompt_template ci_errors
  technology=$(jq '.technology' "$PRD_FILE")
  reference_repos=$(jq '.reference_repos' "$PRD_FILE")
  specs_dir=$(jq -r '.specs_dir // "specs/"' "$PRD_FILE")
  progress_content=$(cat "$PROGRESS_FILE")
  prompt_template=$(cat "$PROMPT_FILE")
  ci_errors=""
  if [ -f "$OUTPUT_DIR/ci_errors.txt" ]; then
    ci_errors=$(cat "$OUTPUT_DIR/ci_errors.txt")
  fi

  if [ -z "$ci_errors" ]; then
    ci_errors="No errors from previous iteration."
  fi

  local story_specs specs_list
  story_specs=$(echo "$story" | jq -r '.specs // empty')
  specs_list=""

  if [ -n "$story_specs" ] && [ "$story_specs" != "null" ]; then
    specs_list="**Required for this story:**
$(echo "$story" | jq -r '.specs[]' 2>/dev/null | while read -r spec; do
      echo "- \`${specs_dir}${spec}\`"
    done)

"
  fi

  specs_list="${specs_list}**All available specs in \`${specs_dir}\`:**
$(jq -r '.available_specs[]' "$PRD_FILE" 2>/dev/null | while read -r spec; do
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

  local story
  story=$(get_current_story)
  if [ -z "$story" ] || [ "$story" = "null" ]; then
    log "SUCCESS" "No more stories to process"
    return 0
  fi

  local story_id story_title story_phase
  story_id=$(get_story_id "$story")
  story_title=$(get_story_title "$story")
  story_phase=$(get_story_phase "$story")

  log "INFO" "Starting iteration $iteration of $MAX_ITERATIONS"
  log "INFO" "Story: $story_id - $story_title"
  log "INFO" "PRD Status: $(get_prd_status)"

  update_story_status "$story_id" "in_progress"

  local prompt
  prompt=$(build_prompt "$iteration" "$story")

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

  local start_time iteration completed
  start_time=$(date +%s)
  iteration=1
  completed=false

  while [ $iteration -le $MAX_ITERATIONS ]; do
    log "INFO" "------------------------------------------"
    log "INFO" "ITERATION $iteration / $MAX_ITERATIONS"
    log "INFO" "------------------------------------------"

    local incomplete
    incomplete=$(count_incomplete_stories)
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

  local end_time duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))

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
