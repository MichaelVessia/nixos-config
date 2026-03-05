---
name: update-pr-description-and-title
description: Update the current PR description from the repo PR template and set a conventional-commit title based on the PR changes.
allowed-tools: Bash(gh pr edit:*), Bash(gh pr view:*), Read, Glob
model: claude-sonnet-4-6
---

## Context

- Current PR: !`gh pr view --json number,title,url,body,files,commits,baseRefName 2>/dev/null || echo "No PR found"`

## Your task

Update the current PR's description to adhere to the repository's PR template,
then set the PR title in conventional-commit format.

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
5. Generate a conventional-commit PR title from the actual PR changes:
   - Prefer the dominant type from commit prefixes when available (`feat`,
     `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `build`, `perf`).
   - Otherwise infer type from changed files and behavior.
   - Use a concise scope when obvious from touched paths.
   - Format exactly as `<type>(<scope>): <summary>` if scope exists, otherwise
     `<type>: <summary>`.
   - Keep title lowercase (except proper nouns), imperative, and at most 72
     chars.
6. Apply both updates in one command with `gh pr edit --title ... --body ...`.
