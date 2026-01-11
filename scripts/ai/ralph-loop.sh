#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

for ((i=1; i<=$1; i++)); do
  echo "Iteration $i"
  echo "--------------------------------"

  result=$(claude --permission-mode acceptEdits -p "@plans/prd.json @plans/progress.txt \
IMPORTANT: Never use AskUserQuestion. Make autonomous decisions. If uncertain, pick the simplest approach and document your reasoning in progress.txt. \
1. Find the highest-priority feature to work on and work only on that feature. \
This should be the one YOU decide has the highest priority - not necessarily the first in the list. \
2. Run typecheck and tests to verify the implementation. \
3. After completing a user story, set its \`passes: true\` in plans/prd.json and add notes describing what was done. \
4. Append your progress to plans/progress.txt. Use this to leave a note for the next person working in the codebase. \
5. Make a git commit of that feature. \
ONLY WORK ON A SINGLE FEATURE. \
If all features are complete, create a file called plans/.complete \
")
  echo "$result"

  if [ -f "plans/.complete" ]; then
    rm -f "plans/.complete"
    echo "PRD complete, exiting."
    notify-send "Ralph" "PRD complete after $i iterations"
    exit 0
  fi
done
