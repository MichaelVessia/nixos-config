---
name: commit-and-push
description: Commit changes and push to remote
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git push:*), Bash(git branch:*)
---

## Context

- Current git status: !`git status`
- Current git diff (unstaged changes): !`git diff`
- Current git diff (staged changes): !`git diff --cached`
- Current branch: !`git branch --show-current`

## Your task

Stage all changes, create a single commit, and push to the remote branch:

1. Stage all modified, added, and deleted files using appropriate `git add`
   commands.
2. Create a commit with a descriptive message that summarizes all the changes.
   DO NOT include any AI-generated attribution text in the commit message.
3. Push the commit to the remote branch.

You have the capability to call multiple tools in a single response. You MUST
do all of the above in a single message using sequential `Bash` calls — they
execute in order within one message, so `git add` → `git commit` → `git push`
runs as expected. Do not use any other tools or do anything else. Do not send
any other text or messages besides these tool calls.

**Do not invoke a sub-skill (e.g. `commit-all`) here.** The `Skill` tool loads
instructions for the next turn rather than executing them on this turn; bundling
a `Skill` call with `git push` in the same message causes the push to run
against an empty branch. Inline the staging and committing as direct `git`
commands instead.
