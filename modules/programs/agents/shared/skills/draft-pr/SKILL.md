---
name: draft-pr
description: Commit, push, and open a draft PR
allowed-tools: Bash(git checkout --branch:*), Bash(git branch:*), Bash(gh pr create:*), Skill
model: claude-sonnet-4-6
---

## Context

- Current branch: !`git branch --show-current`

## Your task

1. If on main, create a new branch. If provided as an argument, include the JIRA
   ticket in the branch name.
2. Invoke `commit-and-push` to stage, commit, and push all changes.
3. Create a pull request using `gh pr create --draft`. Ensure the PR title
   adheres to conventional commits format.
4. Invoke `update-pr-description` to update the PR description to match the
   repo's PR template.
