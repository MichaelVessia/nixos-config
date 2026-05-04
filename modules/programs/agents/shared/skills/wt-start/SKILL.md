---
name: wt-start
description: Create a new branch in a fresh worktree and move into it
allowed-tools: Bash(wt switch:*), Bash(wt list:*), Bash(jq:*), Bash(cd:*)
---

## Your task

Spin up an isolated worktree for a new branch and land inside it.

1. Take the branch name from the user's argument. If no argument was provided,
   ask the user for one before continuing.
2. Run `wt switch --create <branch> --no-cd` to create the worktree and branch
   off the default branch. `--no-cd` skips the shell integration so we can
   change directory explicitly in the next step.
3. Resolve the new worktree path:
   `wt list --format json | jq -r '.[] | select(.branch=="<branch>") | .path'`
4. `cd` into that path so subsequent tool calls run inside the new worktree.
5. Print the new path and stop. Do not start implementation work.
