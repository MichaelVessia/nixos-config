---
name: open-draft-pr
description: |
  Commit, push, and open a draft PR. Use when work is in-progress, when CI
  needs to run before review, or when the user says "draft PR", "open as
  draft", "WIP PR". For a ready-for-review PR, use `open-pr` instead.
allowed-tools: Bash(git checkout --branch:*), Bash(git branch:*), Bash(gh pr create:*), Skill
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

## Sequencing

Each numbered step runs in its own message. The `Skill` tool loads
instructions for the *next* turn; it does not execute them on the current
turn. Do **not** bundle a `Skill` invocation with later steps (e.g. running
`gh pr create --draft` in the same message that invokes `commit-and-push`) —
the PR will be created against an empty branch because the commit-and-push
instructions have not run yet. Wait for each invoked skill to complete before
starting the next step.
