---
name: wt-finish
description: Squash, rebase, fast-forward into the default branch, then remove the worktree
allowed-tools: Bash(wt merge:*), Bash(wt list:*), Bash(git status:*), Bash(git branch:*)
model: claude-sonnet-4-6
---

## Context

- Current branch: !`git branch --show-current`
- Working tree: !`git status --short`

## Your task

Finish the current feature branch locally using `wt merge`.

1. Verify we're on a feature branch (not the default branch). If we're on the
   default branch, stop and tell the user there's nothing to merge.
2. If the working tree has uncommitted changes, report them and ask the user
   whether to include them (`wt merge` will stage+commit by default) or bail.
3. Run `wt merge`. This squashes commits since the branch point, rebases onto
   the default branch, fast-forwards the default branch, and removes the
   worktree. The shell will land back at the repo root.
4. Report the resulting commit sha on the default branch and stop.
