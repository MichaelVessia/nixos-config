---
name: open-draft-pr
description: |
  Commit, push, and open a draft PR. Use when work is in-progress, when CI
  needs to run before review, or when the user says "draft PR", "open as
  draft", "WIP PR". For a ready-for-review PR, use `open-pr` instead.
allowed-tools: Bash(git checkout --branch:*), Bash(git branch:*), Bash(gh pr create:*), Skill
model: sonnet
---

## Context

- Current branch: !`git branch --show-current`

## Your task

1. If on main, create a new branch. If provided as an argument, include the JIRA
   ticket in the branch name.
2. Invoke `commit-and-push` to stage, commit, and push all changes.
3. Create the pull request using `gh pr create --draft`. A placeholder title
   is fine — `update-pr-title` will normalize it next.
4. Invoke `update-pr-title` to set the best-fitting conventional-commit title.
5. Invoke `update-pr-description` to fill the body from the repo's PR
   template.
