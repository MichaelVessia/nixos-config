---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git push:*), Bash(git commit:*)
description: Commit changes and push to remote
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`

## Your task

Based on the above changes:

1. Stage any changed files with appropriate commit message
2. Create a single commit with a descriptive message. DO NOT include any Claude
   attribution or "Generated with Claude Code" text in the commit message.
3. Push the changes to the remote branch
4. You have the capability to call multiple tools in a single response. You MUST
   do all of the above in a single message. Do not use any other tools or do
   anything else. Do not send any other text or messages besides these tool
   calls.
