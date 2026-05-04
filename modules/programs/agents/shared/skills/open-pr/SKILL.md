---
name: open-pr
description: |
  Commit, push, and open a ready-for-review PR (non-draft). Use when the work
  is complete and reviewable, or when the user says "open PR", "open a PR",
  "ship it for review". For an in-progress PR, use `open-draft-pr` instead.
allowed-tools: Bash(git checkout --branch:*), Bash(git branch:*), Bash(gh pr create:*), Skill
---

## Context

- Current branch: !`git branch --show-current`

## Your task

1. If on main, create a new branch. If provided as an argument, include the JIRA
   ticket in the branch name.
2. Invoke `commit-and-push` to stage, commit, and push all changes.
3. Create the pull request using `gh pr create` (no `--draft`). A placeholder
   title is fine — `update-pr-title` will normalize it next.
4. Invoke `update-pr-title` to set the best-fitting conventional-commit title.
5. Invoke `update-pr-description` to fill the body from the repo's PR
   template.
