---
name: commit-and-push
description: Commit changes and push to remote
allowed-tools: Bash(git push:*), Bash(git branch:*), Skill
---

## Context

- Current branch: !`git branch --show-current`

## Your task

1. Invoke `commit-all` to stage all changes and create a commit.
2. Push the commit to the remote branch.
3. You have the capability to call multiple tools in a single response. You MUST
   do all of the above in a single message. Do not use any other tools or do
   anything else. Do not send any other text or messages besides these tool
   calls.
