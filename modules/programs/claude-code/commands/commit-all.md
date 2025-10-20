---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Stage all changed files and create a commit
---

## Context

- Current git status: !`git status`
- Current git diff (unstaged changes): !`git diff`
- Current git diff (staged changes): !`git diff --cached`

## Your task

Stage all changed files and create a single commit:

1. Stage all modified, added, and deleted files using appropriate git add
   commands
2. Create a commit with a descriptive message that summarizes all the changes.
   DO NOT include any Claude attribution or "Generated with Claude Code" text in
   the commit message.
3. You have the capability to call multiple tools in a single response. You MUST
   do all of the above in a single message. Do not use any other tools or do
   anything else. Do not send any other text or messages besides these tool
   calls.
