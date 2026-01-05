#!/usr/bin/env bash
# Ralph Wiggum AI Coding Approach
# Runs claude in a loop until work is complete or max iterations reached

set -euo pipefail

MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-10}"
COMPLETE_MARKER="<promise>COMPLETE</promise>"
TASK_FILE=""

usage() {
    cat <<EOF
Usage: ralph [OPTIONS] [TASK_FILE]

Unattended autonomous coding loop. Repeatedly invokes claude with a task
until complete or max iterations reached.

Invoke via: /ralph <task description>

Arguments:
    TASK_FILE               File containing task description (markdown, text, etc.)

Options:
    -n, --max-iterations NUM    Maximum iterations (default: 10)
    -p, --prompt TEXT           Inline task prompt (instead of file)
    -h, --help                  Show this help

Environment:
    RALPH_MAX_ITERATIONS        Default max iterations

Examples:
    /ralph Add dark mode to settings page
    /ralph Implement the features described in TODO.md
EOF
    exit 0
}

PROMPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--max-iterations) MAX_ITERATIONS="$2"; shift 2 ;;
        -p|--prompt) PROMPT="$2"; shift 2 ;;
        -h|--help) usage ;;
        -*) echo "Unknown option: $1"; usage ;;
        *) TASK_FILE="$1"; shift ;;
    esac
done

# Build the prompt for claude
if [[ -n "$PROMPT" ]]; then
    TASK_CONTENT="$PROMPT"
elif [[ -n "$TASK_FILE" && -f "$TASK_FILE" ]]; then
    TASK_CONTENT=$(cat "$TASK_FILE")
else
    echo "Error: Provide a task file or use -p for inline prompt"
    usage
fi

# The prompt sent to each fresh claude session
RALPH_PROMPT="You are running in Ralph mode: an autonomous loop working on a task.

## Task
$TASK_CONTENT

## Rules
1. **Scope small**: Pick ONE concrete subtask. Do not try to do everything at once.
2. **Keep CI green**: Every commit must pass tests and typechecks. Run them before committing.
3. **Commit often**: Make atomic commits as you complete each piece of work.
4. **Track progress**: Append to progress.txt after each commit (create if missing).

## Progress Tracking
After each commit, append an entry to progress.txt:
\`\`\`
## [ISO_DATE] - [SHORT_DESCRIPTION]
- What was done
- Files changed
- Next steps (if any)
\`\`\`

## Workflow
1. Read progress.txt if it exists to understand prior work
2. Analyze what remains to be done for the task
3. Pick the smallest concrete next step
4. Implement it
5. Run tests/typechecks
6. Commit with descriptive message
7. Append to progress.txt
8. Evaluate: is the task complete?

## Completion
If the task is fully complete (all requirements met, tests pass, nothing left to do):

<promise>COMPLETE</promise>

If work remains, end your response normally. The loop will invoke you again with fresh context.

## Important
- Do NOT emit <promise>COMPLETE</promise> unless truly done
- Do NOT try to finish everything in one iteration
- Each iteration should make meaningful progress on ONE thing
- Read progress.txt at the start to avoid repeating work"

echo "Starting Ralph Wiggum loop (max $MAX_ITERATIONS iterations)"
echo "Task: $TASK_CONTENT"
echo "================================================"

for i in $(seq 1 "$MAX_ITERATIONS"); do
    echo ""
    echo "=== Iteration $i/$MAX_ITERATIONS ==="
    echo ""
    
    # Run claude with the embedded prompt
    OUTPUT=$(claude --print "$RALPH_PROMPT" 2>&1) || true
    
    echo "$OUTPUT"
    
    # Check for completion marker
    if echo "$OUTPUT" | grep -q "$COMPLETE_MARKER"; then
        echo ""
        echo "================================================"
        echo "Ralph complete after $i iteration(s)"
        exit 0
    fi
    
    echo ""
    echo "--- Iteration $i complete, continuing... ---"
done

echo ""
echo "================================================"
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing"
echo "Review progress.txt to see what's done"
exit 1
