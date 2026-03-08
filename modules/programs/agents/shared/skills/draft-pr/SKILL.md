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
3. Determine the correct conventional commit type by analyzing the actual changes
   (diffs, commit messages, files touched). Use the full range of types:
   - `feat` - new user-facing functionality
   - `fix` - bug fix
   - `refactor` - restructuring without behavior change
   - `chore` - maintenance, dependency bumps, config changes
   - `docs` - documentation only
   - `test` - adding or updating tests only
   - `ci` - CI/CD pipeline changes
   - `build` - build system or tooling changes
   - `perf` - performance improvement
   - `style` - formatting, whitespace, naming (no logic change)
   Do NOT default to `feat`. Pick the type that most accurately describes the
   dominant intent of the changes.
4. Create a pull request using `gh pr create --draft` with the determined
   conventional commit title.
5. Invoke `update-pr-description-and-title` to fill in the PR description from
   the repo's template and normalize the title.
