---
allowed-tools: Bash(git diff:*), Bash(git status:*)
description: Generate a conventional commit message for staged changes
---

## Context

- Current git status: !`git status`
- Staged changes: !`git diff --cached`

## Your task

Generate a commit message in conventional commits format based on the staged
changes.

Requirements:

1. Use conventional commits format: `<type>(<scope>): <subject>`
2. Types: feat, fix, docs, style, refactor, perf, test, chore, ci, build
3. Keep subject line under 50 characters
4. Include a body if changes are complex (wrap at 72 characters)
5. DO NOT include any Claude attribution or "Generated with Claude Code" text
6. Only output the commit message - nothing else

You MUST do this in a single message. Do not use any other tools besides reading
the diffs. Do not commit anything.
