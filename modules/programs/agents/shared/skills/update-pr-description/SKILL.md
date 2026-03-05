---
name: update-pr-description
description: Update the current PR description to match the repo's PR template. Use when a PR exists and its description needs to follow the .github/ template.
allowed-tools: Bash(gh pr edit:*), Bash(gh pr view:*), Read, Glob
model: claude-sonnet-4-6
---

## Context

- Current PR: !`gh pr view --json number,title,url,body 2>/dev/null || echo "No PR found"`

## Your task

Update the current PR's description to adhere to the repository's PR template.

1. Find the PR template by checking `.github/PULL_REQUEST_TEMPLATE.md`,
   `.github/PULL_REQUEST_TEMPLATE/`, and `.github/pull_request_template.md`
   using Glob.
2. If a template exists, read it with the Read tool.
3. Update the PR description using `gh pr edit` to follow the template
   structure, filling in sections based on the PR's actual changes. If you don't
   know how to fill out a section, leave it empty.
4. If no template exists, ensure the description includes at minimum:
   - A summary of the changes
   - Steps to test the PR

Do not modify the PR title. Only update the body/description.
