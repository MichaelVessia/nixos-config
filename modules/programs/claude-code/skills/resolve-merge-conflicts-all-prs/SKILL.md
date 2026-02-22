---
name: resolve-merge-conflicts-all-prs
description: Resolve merge conflicts across all open GitHub PRs authored by the current user in the current repository by running resolve-merge-conflicts for each PR.
allowed-tools: Bash(git *), Bash(gh *), Bash(rg *), Bash(npm test*), Bash(bun test*), Bash(pnpm test*), Bash(yarn test*), Bash(pytest*), Bash(go test*), Bash(cargo test*), Read, Edit, Write, Glob, Grep, TodoWrite
---

Resolve merge conflicts in bulk for the current repo.

## Intent

- Reduce toil by processing all open PRs authored by the authenticated user.
- Reuse the `resolve-merge-conflicts` skill for each PR.

## Workflow

1. Create a `TodoWrite` list for repo discovery, PR discovery, and per-PR execution.
2. Validate prerequisites:
   - `git rev-parse --is-inside-work-tree`
   - `gh auth status`
   - Clean working tree required before starting (`git status --porcelain`).
3. Identify repo + actor:
   - `repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)`
   - `me=$(gh api user --jq .login)`
4. Discover target PRs (open, authored by current user in current repo):
   - `gh pr list --repo "$repo" --state open --author "$me" --json number,url,title,updatedAt,headRefName,baseRefName`
   - If none, stop with a short report.
   - Process in most recently updated order.
5. For each PR:
   - Ensure clean working tree before starting that PR.
   - Invoke the `resolve-merge-conflicts` skill with that PR URL/number.
   - If successful, push branch updates (`git push` on the checked-out head branch).
   - Record success/failure and key notes.
   - If one PR fails, continue to next PR unless the failure is global (auth outage, broken repo state).
6. End with a compact report:
   - repo and user,
   - PRs processed,
   - success count, failure count, skipped count,
   - per-PR status with next action for failures.

## Rules

- Do not skip directly to blanket `ours`/`theirs` conflict resolution.
- Do not discard unrelated local changes.
- Keep each PR isolated, never carry partial conflict state into the next PR.
- If `resolve-merge-conflicts` is unavailable, apply its workflow inline for each PR.
