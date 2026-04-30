---
name: update-pr-description
description: Fill the current PR's description from the repo's PR template (or a sane default), focused on intent and motivation rather than a changelog.
allowed-tools: Bash(gh pr edit:*), Bash(gh pr view:*), Read, Glob
model: claude-sonnet-4-6
---

## Context

- Current PR: !`gh pr view --json number,title,url,body,files,commits,baseRefName 2>/dev/null || echo "No PR found"`

## Your task

Update the current PR's description to match the repository's PR template,
filled out from the perspective of *why* this PR exists.

### 1. Locate the template

Use Glob to check, in order:

- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/pull_request_template.md`
- `.github/PULL_REQUEST_TEMPLATE/` (directory of multiple templates)

If a template exists, read it.

### 2. Fill it in

Focus on **overall intent and motivation** of the PR. Do NOT:

- Enumerate specific files changed
- List every commit or diff
- Describe mechanical edits (renames, imports, etc.)

Instead, explain:

- **Why** the change was made and what problem it solves
- Important design decisions or trade-offs
- Anything a reviewer needs to know that isn't obvious from the diff

If a template section doesn't apply or you don't have the information, leave
it empty rather than padding.

### 3. No template fallback

If no template exists, write a description with at minimum:

- A concise summary of intent and motivation (not a changelog)
- Steps to test the PR

### 4. Apply

```
gh pr edit --body "<description>"
```

Report what was set.
