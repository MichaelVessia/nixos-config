---
name: wt-prune
description: Remove worktrees whose branches have merged into the default branch
allowed-tools: Bash(wt list:*), Bash(wt step prune:*)
model: claude-sonnet-4-6
---

## Context

- Current worktrees: !`wt list --format json`

## Your task

Clean up stale worktrees.

1. Review the `wt list` output in context. If nothing looks merged/stale, say
   so and stop.
2. Run `wt step prune` to remove worktrees whose branches are already merged
   into the default branch.
3. Report what was removed (diff the list against the post-prune state) and
   stop.
