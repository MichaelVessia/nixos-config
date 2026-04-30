---
name: wt-pr
description: Check out a GitHub PR in its own worktree for review
allowed-tools: Bash(wt switch:*), Bash(wt list:*), Bash(jq:*), Bash(cd:*)
model: sonnet
---

## Your task

Put the user inside an isolated worktree containing the PR's branch.

1. Take the PR number from the user's argument. If none was provided, ask for
   one before continuing.
2. Run `wt switch pr:<N> --no-cd` to fetch the PR and materialise it as a
   worktree. `--no-cd` skips shell integration so we can `cd` explicitly.
3. Resolve the worktree path for the PR branch:
   `wt list --format json | jq -r '.[] | select(.branch | test("pr.*<N>|/<N>$")) | .path' | head -1`
   If that yields nothing, fall back to the most recently added entry in
   `wt list --format json`.
4. `cd` into that path so review happens inside the PR's worktree.
5. Print the branch name and path, then stop. Do not start reviewing unless
   the user asked for a review.
