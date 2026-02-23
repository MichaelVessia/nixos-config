#!/usr/bin/env bash

# Ralph Auto Loop - Autonomous coding loop with required focus prompt.
# Agent-specific wrappers set RALPH_AGENT to "claude" or "codex".

set -euo pipefail

AGENT="${RALPH_AGENT:-}"
if [ -z "$AGENT" ]; then
  echo "Error: RALPH_AGENT must be set (claude|codex)"
  exit 1
fi

SKIP_CHECKS=false
FOCUS_PROMPT=""
MAX_ITERATIONS=0
USE_JUDGE=false
JUDGE_FIRST=false
CONFIG_FILE="ralph/ralph-auto-${AGENT}.jsonc"
if [ -n "${RALPH_DEFAULT_CONFIG:-}" ]; then
  CONFIG_FILE="$RALPH_DEFAULT_CONFIG"
fi

usage() {
  cat <<EOF
Usage: ./ralph/ralph-auto-${AGENT}.sh <focus prompt> [options]

Options:
  --config <path>       Config JSONC path (default: $CONFIG_FILE)
  --skip-checks         Skip CI checks
  --max-iterations <n>  Limit iterations (0 = unlimited)
  --judge               Enable judge agent
  --judge-first         Run judge before starting
  --help, -h            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --config)
    if [ -n "${2:-}" ]; then
      CONFIG_FILE="$2"
      shift 2
    else
      echo "Error: --config requires a file path"
      exit 1
    fi
    ;;
  --skip-checks)
    SKIP_CHECKS=true
    shift
    ;;
  --max-iterations)
    if [[ -n "${2:-}" && "${2:-}" =~ ^[0-9]+$ ]]; then
      MAX_ITERATIONS="$2"
      shift 2
    else
      echo "Error: --max-iterations requires a non-negative integer"
      exit 1
    fi
    ;;
  --judge)
    USE_JUDGE=true
    shift
    ;;
  --judge-first)
    JUDGE_FIRST=true
    USE_JUDGE=true
    shift
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  -*)
    echo "Unknown option: $1"
    usage
    exit 1
    ;;
  *)
    if [ -z "$FOCUS_PROMPT" ]; then
      FOCUS_PROMPT="$1"
    else
      echo "Error: Multiple focus prompts provided"
      exit 1
    fi
    shift
    ;;
  esac
done

if [ -z "$FOCUS_PROMPT" ]; then
  echo "Error: A focus prompt is required"
  usage
  exit 1
fi

COMPLETE_MARKER="NOTHING_LEFT_TO_DO"
OUTPUT_DIR=".ralph-auto"
RALPH_DIR="ralph"

SPECS_DIR=""
AGENT_MODEL=""
AGENT_VARIANT=""
COMMIT_PREFIX=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

parse_jsonc() {
  sed 's|//.*$||g; s|/\*.*\*/||g' "$CONFIG_FILE" | jq -c '.'
}

load_config() {
  local config
  config=$(parse_jsonc)
  SPECS_DIR=$(echo "$config" | jq -r '.specsDir // empty')
  COMMIT_PREFIX=$(echo "$config" | jq -r '.commitPrefix // empty')
  AGENT_MODEL=$(echo "$config" | jq -r '.model // empty')
  AGENT_VARIANT=$(echo "$config" | jq -r '.variant // empty')
}

cleanup() {
  pkill -P $$ 2>/dev/null || true
  if [ -d "$OUTPUT_DIR" ]; then
    rm -rf "$OUTPUT_DIR"
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Cleaned up $OUTPUT_DIR"
  fi
}

handle_signal() {
  echo ""
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} Received interrupt signal, shutting down..."
  cleanup
  exit 130
}

trap cleanup EXIT
trap handle_signal INT TERM

mkdir -p "$OUTPUT_DIR"

log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  case "$level" in
  "INFO") echo -e "${BLUE}[$timestamp]${NC} $message" ;;
  "SUCCESS") echo -e "${GREEN}[$timestamp]${NC} $message" ;;
  "WARN") echo -e "${YELLOW}[$timestamp]${NC} $message" ;;
  "ERROR") echo -e "${RED}[$timestamp]${NC} $message" ;;
  esac
  echo "[$timestamp] [$level] $message" >>"$OUTPUT_DIR/ralph-auto.log"
}

extract_text_from_jsonl() {
  local file="$1"
  jq -r '
    if .type == "text" then .part.text // empty
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
  ' "$file" 2>/dev/null || true
}

stream_filter() {
  if [ ! -x "$RALPH_DIR/scripts/stream-filter.sh" ]; then
    cat
    return
  fi
  "$RALPH_DIR/scripts/stream-filter.sh"
}

collect_assistant_text() {
  local file="$1"
  local extracted
  extracted=$(extract_text_from_jsonl "$file")
  if [ -n "$extracted" ]; then
    echo "$extracted"
  else
    cat "$file"
  fi
}

load_ci_checks() {
  parse_jsonc | jq -c '.checks'
}

check_prerequisites() {
  log "INFO" "Checking prerequisites..."

  case "$AGENT" in
  claude)
    command -v claude &>/dev/null || {
      log "ERROR" "Claude Code CLI is not installed"
      exit 1
    }
    ;;
  codex)
    command -v codex &>/dev/null || {
      log "ERROR" "Codex CLI is not installed"
      exit 1
    }
    ;;
  *)
    log "ERROR" "Unsupported agent: $AGENT"
    exit 1
    ;;
  esac

  command -v jq &>/dev/null || {
    log "ERROR" "jq is not installed"
    exit 1
  }

  git rev-parse --git-dir >/dev/null 2>&1 || {
    log "ERROR" "Not in a git repository"
    exit 1
  }

  [ -f "$CONFIG_FILE" ] || {
    log "ERROR" "$CONFIG_FILE not found"
    exit 1
  }

  local config
  config=$(parse_jsonc) || {
    log "ERROR" "$CONFIG_FILE is not valid JSON"
    exit 1
  }

  local missing=""
  echo "$config" | jq -e '.specsDir' >/dev/null 2>&1 || missing+=" specsDir"
  echo "$config" | jq -e '.model' >/dev/null 2>&1 || missing+=" model"
  echo "$config" | jq -e '.variant' >/dev/null 2>&1 || missing+=" variant"
  echo "$config" | jq -e '.commitPrefix' >/dev/null 2>&1 || missing+=" commitPrefix"
  echo "$config" | jq -e '.checks | length > 0' >/dev/null 2>&1 || missing+=" checks"

  if [ -n "$missing" ]; then
    log "ERROR" "$CONFIG_FILE missing required fields:$missing"
    exit 1
  fi

  load_config

  [ -d "$SPECS_DIR" ] || {
    log "ERROR" "$SPECS_DIR directory not found"
    exit 1
  }

  local spec_count
  spec_count=$(find "$SPECS_DIR" -name "*.md" -type f | wc -l | tr -d ' ')
  [ "$spec_count" -gt 0 ] || {
    log "ERROR" "No .md files found in $SPECS_DIR"
    exit 1
  }

  log "INFO" "Agent: $AGENT (model: $AGENT_MODEL, variant: $AGENT_VARIANT)"
  log "INFO" "Found $spec_count spec file(s) in $SPECS_DIR"
  log "SUCCESS" "Prerequisites check passed"
}

has_changes() {
  ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]
}

run_ci_checks() {
  log "INFO" "Running CI checks..."

  local ci_failed=0
  local error_output=""
  local checks
  checks=$(load_ci_checks)
  local check_count
  check_count=$(echo "$checks" | jq 'length')

  echo "=========================================="
  echo "Running CI Checks"
  echo "=========================================="

  local i=0
  while [ "$i" -lt "$check_count" ]; do
    local name command check_output
    name=$(echo "$checks" | jq -r ".[$i].name")
    command=$(echo "$checks" | jq -r ".[$i].command")

    echo -e "\n$((i + 1)). $name...\n$(printf '%*s' ${#name} '' | tr ' ' '-')---"
    if check_output=$(eval "$command" 2>&1); then
      echo -e "${GREEN}$name passed${NC}"
    else
      echo -e "${RED}$name failed${NC}"
      ci_failed=1
      error_output+="## $name Failed\n\`\`\`\n$check_output\n\`\`\`\n\n"
    fi
    i=$((i + 1))
  done

  echo -e "\n=========================================="
  if [ "$ci_failed" -eq 0 ]; then
    echo -e "${GREEN}All CI checks passed!${NC}"
    log "SUCCESS" "CI checks passed"
    return 0
  fi

  echo -e "${RED}CI checks failed!${NC}"
  log "ERROR" "CI checks failed"
  echo -e "# CI Check Failures\n\n$error_output" >"$OUTPUT_DIR/ci_errors.txt"
  return 1
}

commit_changes() {
  local iteration="$1"
  local task_summary="$2"
  log "INFO" "Committing changes..."
  git add -A
  if git diff --cached --quiet; then
    log "WARN" "No changes to commit"
    return 0
  fi
  if git commit -m "$COMMIT_PREFIX: $task_summary

Ralph-Auto-Iteration: $iteration
Ralph-Auto-Agent: $AGENT

Automated commit by Ralph Auto loop."; then
    log "SUCCESS" "Committed: $task_summary"
    return 0
  fi
  log "ERROR" "Commit failed"
  return 1
}

rollback_changes() {
  log "WARN" "Rolling back uncommitted changes..."
  git checkout -- .
  git clean -fd
}

build_prompt() {
  local iteration="$1"
  local ci_errors=""
  local focus_section=""

  if [ -f "$OUTPUT_DIR/ci_errors.txt" ]; then
    ci_errors="## Previous Iteration Errors

**CI checks failed. You MUST fix these errors.**

Read: \`$OUTPUT_DIR/ci_errors.txt\`
"
  fi

  if [ -n "$FOCUS_PROMPT" ]; then
    focus_section="## FOCUS MODE

**Work ONLY on:** $FOCUS_PROMPT

Signal TASK_COMPLETE when done.
"
  fi

  local specs_list
  specs_list=$(find "$SPECS_DIR" -name "*.md" -type f | sort | while read -r file; do echo "- \`$file\`"; done)

  local checks_list=""
  local commands_table=""
  local checks
  checks=$(load_ci_checks)
  local check_count i
  check_count=$(echo "$checks" | jq 'length')
  i=0
  while [ "$i" -lt "$check_count" ]; do
    local name command
    name=$(echo "$checks" | jq -r ".[$i].name")
    command=$(echo "$checks" | jq -r ".[$i].command")
    checks_list+="$((i + 1)). \`$command\` - $name must pass
"
    commands_table+="| \`$command\` | $name (CI) |
"
    i=$((i + 1))
  done

  local extra_commands extra_count
  extra_commands=$(parse_jsonc | jq -c '.commands // []')
  extra_count=$(echo "$extra_commands" | jq 'length')
  i=0
  while [ "$i" -lt "$extra_count" ]; do
    local name command
    name=$(echo "$extra_commands" | jq -r ".[$i].name")
    command=$(echo "$extra_commands" | jq -r ".[$i].command")
    commands_table+="| \`$command\` | $name |
"
    i=$((i + 1))
  done

  cat <<PROMPT_EOF
# Ralph Auto Loop - Autonomous Implementation Agent

You are an autonomous coding agent working on a focused topic.

## Focus Mode

The **focus input** specifies the topic you should work on. Within that topic:
- You **select your own tasks** based on what needs to be done
- You complete **one task at a time**, then signal completion
- You **update specs** to track task status as you work
- You may **create new tasks** if you discover they are needed
- When all work for the focus topic is complete, signal that nothing is left to do

## The $SPECS_DIR Directory

The \`$SPECS_DIR\` directory contains documentation about this application:
- Implementation plans
- Best practices
- Architecture context

Use these files as reference when implementing tasks. Read relevant specs before making changes.

**Available specs:**

$specs_list

## Critical Rules

1. **STAY ON TOPIC**: Work only on tasks related to the focus input
2. **DO NOT COMMIT**: The Ralph Auto script handles git commits
3. **CI MUST BE GREEN**: Code must pass all checks before signaling completion
4. **ONE TASK PER ITERATION**: Complete one task, signal completion, then STOP
5. **UPDATE SPECS**: Update spec files to mark tasks complete or add discovered tasks

## Signals

### TASK_COMPLETE

When one task is finished and CI is green, output exactly:

\`\`\`
TASK_COMPLETE: Brief description of what you implemented
\`\`\`

### NOTHING_LEFT_TO_DO

When all tasks for the focus topic are done:

\`\`\`
NOTHING_LEFT_TO_DO
\`\`\`

If you complete the final task, output BOTH:
\`\`\`
TASK_COMPLETE: Brief description of what you implemented

NOTHING_LEFT_TO_DO
\`\`\`

## CI Green Requirement

Before signaling TASK_COMPLETE, run these checks in order:

$checks_list

### Command Reference

| Command | Description |
|---|---|
$commands_table
## Workflow

1. Check CI status, fix prior failures first
2. Read relevant specs
3. Select one task
4. Implement
5. Verify CI
6. Update specs
7. Signal completion
8. STOP

## Important Reminders

- Read \`AGENTS.md\` for project conventions
- Do not run git commit/reset commands
- If you discover new required work in scope, add it to specs

---

## Iteration

This is iteration $iteration.

$focus_section
$ci_errors
## Begin

Review the focus topic and select one task.
PROMPT_EOF
}

extract_task_description() {
  local output_file="$1"
  local desc
  desc=$(collect_assistant_text "$output_file" | sed -n 's/.*TASK_COMPLETE:[[:space:]]*//p' | head -1 | tr -d '\r' || true)
  if [ -n "$desc" ]; then
    echo "$desc"
    return
  fi
  desc=$(grep -o 'TASK_COMPLETE:[^"]*' "$output_file" | head -1 | sed 's/TASK_COMPLETE:[[:space:]]*//' | tr -d '\r' || true)
  if [ -n "$desc" ]; then
    echo "$desc"
  else
    echo "Autonomous improvements"
  fi
}

build_judge_prompt() {
  local focus="$1"
  local specs_list
  specs_list=$(find "$SPECS_DIR" -name "*.md" -type f | sort | while read -r file; do echo "- \`$file\`"; done)

  cat <<EOF
# Judge Agent - Work Completion Review

Review whether the focus area has been fully implemented.

**Focus:** $focus

## Available Specs

$specs_list

## Checklist

1. Spec completion state
2. TODO/FIXME/unimplemented markers
3. Implementation vs stated requirements
4. Test coverage and ignored tests
5. Integration (not dead code)

## Verdict

Output exactly one:

MORE_WORK_TO_DO

or

ALL_WORK_DONE
EOF
}

run_agent() {
  local prompt_file="$1"
  local output_file="$2"
  local stderr_file="$3"

  case "$AGENT" in
  claude)
    if [ "$AGENT_VARIANT" = "default" ] || [ -z "$AGENT_VARIANT" ]; then
      cat "$prompt_file" |
        claude --dangerously-skip-permissions --verbose --model "$AGENT_MODEL" --print --output-format stream-json 2>"$stderr_file" |
        tee "$output_file" | stream_filter
    else
      cat "$prompt_file" |
        claude --dangerously-skip-permissions --verbose --model "$AGENT_MODEL" --effort "$AGENT_VARIANT" --print --output-format stream-json 2>"$stderr_file" |
        tee "$output_file" | stream_filter
    fi
    ;;
  codex)
    if [ "$AGENT_VARIANT" = "default" ] || [ -z "$AGENT_VARIANT" ]; then
      cat "$prompt_file" |
        codex exec --full-auto --json -m "$AGENT_MODEL" - 2>"$stderr_file" |
        tee "$output_file" | stream_filter
    else
      cat "$prompt_file" |
        codex exec --full-auto --json -m "$AGENT_MODEL" -p "$AGENT_VARIANT" - 2>"$stderr_file" |
        tee "$output_file" | stream_filter
    fi
    ;;
  *)
    log "ERROR" "Unsupported agent: $AGENT"
    return 1
    ;;
  esac
}

run_judge() {
  local iteration="$1"
  local judge_output_file="$OUTPUT_DIR/iteration_${iteration}_judge_output.txt"
  local judge_stderr_file="$OUTPUT_DIR/iteration_${iteration}_judge_stderr.txt"
  local judge_prompt_file="$OUTPUT_DIR/iteration_${iteration}_judge_prompt.md"

  log "INFO" "Running judge..."
  build_judge_prompt "$FOCUS_PROMPT" >"$judge_prompt_file"

  local judge_exit_code=0
  if run_agent "$judge_prompt_file" "$judge_output_file" "$judge_stderr_file"; then
    log "SUCCESS" "Judge completed"
  else
    judge_exit_code=$?
    if [ "$judge_exit_code" -eq 130 ] || [ "$judge_exit_code" -eq 143 ]; then
      log "INFO" "Judge interrupted"
      return 2
    fi
    log "WARN" "Judge exited with status $judge_exit_code"
  fi

  local judge_text judge_flat
  judge_text=$(collect_assistant_text "$judge_output_file")
  judge_flat=$(echo "$judge_text" | tr -d '\r' | tr '\n' ' ')

  if echo "$judge_flat" | grep -qE "(MORE_WORK_TO_DO|MORE WORK TO DO)"; then
    log "WARN" "Judge says: MORE_WORK_TO_DO"
    return 1
  fi
  if echo "$judge_flat" | grep -qE "(ALL_WORK_DONE|ALL WORK DONE)"; then
    log "SUCCESS" "Judge says: ALL_WORK_DONE"
    return 0
  fi

  log "ERROR" "Judge did not produce a verdict, assuming MORE_WORK_TO_DO"
  return 1
}

run_iteration() {
  local iteration="$1"
  local output_file="$OUTPUT_DIR/iteration_${iteration}_output.txt"
  local stderr_file="$OUTPUT_DIR/iteration_${iteration}_stderr.txt"
  local prompt_file="$OUTPUT_DIR/iteration_${iteration}_prompt.md"

  log "INFO" "Starting iteration $iteration"

  build_prompt "$iteration" >"$prompt_file"
  log "INFO" "Prompt: $(wc -l <"$prompt_file" | tr -d ' ') lines"

  log "INFO" "Running ${AGENT} agent..."
  echo ""

  local agent_exit_code=0
  if run_agent "$prompt_file" "$output_file" "$stderr_file"; then
    log "SUCCESS" "Agent completed iteration $iteration"
  else
    agent_exit_code=$?
    if [ "$agent_exit_code" -eq 130 ] || [ "$agent_exit_code" -eq 143 ]; then
      log "INFO" "Agent interrupted"
      return 1
    fi
    log "WARN" "Agent exited with status $agent_exit_code"
  fi

  local assistant_text assistant_flat
  assistant_text=$(collect_assistant_text "$output_file")
  assistant_flat=$(echo "$assistant_text" | tr -d '\r' | tr '\n' ' ')

  local has_task_complete=false
  local has_nothing_left=false
  echo "$assistant_flat" | grep -q "TASK_COMPLETE:" && has_task_complete=true
  echo "$assistant_flat" | grep -q "$COMPLETE_MARKER" && has_nothing_left=true

  if [ "$has_task_complete" = true ]; then
    log "INFO" "Agent signaled task completion"
    local task_desc ci_passed
    task_desc=$(extract_task_description "$output_file")
    ci_passed=true

    if [ "$SKIP_CHECKS" = true ]; then
      log "INFO" "Skipping CI checks"
    else
      run_ci_checks || ci_passed=false
    fi

    if [ "$ci_passed" = true ]; then
      rm -f "$OUTPUT_DIR/ci_errors.txt"
      commit_changes "$iteration" "$task_desc" || {
        rollback_changes
        return 1
      }
      log "SUCCESS" "Task completed: $task_desc"
    else
      log "WARN" "CI failed, keeping changes for next iteration"
      return 1
    fi
  elif has_changes; then
    log "WARN" "No TASK_COMPLETE signal but changes detected"
    local ci_passed
    ci_passed=true
    if [ "$SKIP_CHECKS" = true ]; then
      log "INFO" "Skipping CI checks"
    else
      run_ci_checks || ci_passed=false
    fi
    if [ "$ci_passed" = true ]; then
      rm -f "$OUTPUT_DIR/ci_errors.txt"
      commit_changes "$iteration" "Partial work"
    fi
  fi

  if [ "$has_nothing_left" = true ]; then
    log "SUCCESS" "Agent signaled NOTHING_LEFT_TO_DO"
    if [ "$USE_JUDGE" = true ]; then
      local judge_result=0
      run_judge "$iteration" || judge_result=$?
      if [ "$judge_result" -eq 1 ]; then
        log "INFO" "Resuming loop per judge verdict"
        return 1
      elif [ "$judge_result" -eq 2 ]; then
        return 1
      fi
    fi
    return 0
  fi
  return 1
}

main() {
  log "INFO" "=========================================="
  log "INFO" "Starting Ralph Auto Loop"
  log "INFO" "Agent: $AGENT"
  log "INFO" "Focus: $FOCUS_PROMPT"
  [ "$MAX_ITERATIONS" -gt 0 ] && log "INFO" "Max iterations: $MAX_ITERATIONS"
  [ "$USE_JUDGE" = true ] && log "INFO" "Judge: enabled"
  [ "$JUDGE_FIRST" = true ] && log "INFO" "Judge-first: enabled"
  [ "$SKIP_CHECKS" = true ] && log "WARN" "Skip checks: enabled"
  log "INFO" "=========================================="

  check_prerequisites

  local start_time iteration completed
  start_time=$(date +%s)
  iteration=1
  completed=false

  if [ "$SKIP_CHECKS" = true ]; then
    log "INFO" "Skipping initial CI checks"
    rm -f "$OUTPUT_DIR/ci_errors.txt"
  else
    log "INFO" "Running initial CI checks..."
    run_ci_checks && rm -f "$OUTPUT_DIR/ci_errors.txt" || log "WARN" "Initial CI failed"
  fi

  if [ "$JUDGE_FIRST" = true ] && [ "$USE_JUDGE" = true ]; then
    log "INFO" "Running judge before main loop..."
    local judge_result=0
    run_judge 0 || judge_result=$?
    if [ "$judge_result" -eq 0 ]; then
      log "SUCCESS" "Judge says ALL_WORK_DONE before starting"
      completed=true
    elif [ "$judge_result" -eq 2 ]; then
      log "INFO" "Judge interrupted"
      exit 130
    else
      log "INFO" "Judge found remaining work"
    fi
  fi

  if [ "$completed" = true ]; then
    log "INFO" "=========================================="
    log "INFO" "Complete. Iterations: 0, Duration: $(($(date +%s) - start_time))s"
    log "SUCCESS" "All work completed (judge-first)"
    exit 0
  fi

  while true; do
    log "INFO" "------------------------------------------"
    log "INFO" "ITERATION $iteration"
    log "INFO" "------------------------------------------"

    if run_iteration "$iteration"; then
      log "SUCCESS" "Nothing left to do"
      completed=true
      break
    fi

    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
      log "WARN" "Reached max iterations"
      break
    fi

    sleep 2
    iteration=$((iteration + 1))
  done

  log "INFO" "=========================================="
  log "INFO" "Complete. Iterations: $iteration, Duration: $(($(date +%s) - start_time))s"
  [ "$completed" = true ] && log "SUCCESS" "All work completed"
  log "INFO" "Recent commits:"
  git log --oneline -5 --grep="Ralph-Auto" || true
  exit 0
}

main
