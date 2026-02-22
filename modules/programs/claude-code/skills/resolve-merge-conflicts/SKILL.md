---
name: resolve-merge-conflicts
description: Resolve git merge conflicts for a GitHub PR. Accept a PR link/number when provided, otherwise infer the open PR for the current branch.
allowed-tools: Bash(git *), Bash(gh *), Bash(rg *), Bash(npm test*), Bash(bun test*), Bash(pnpm test*), Bash(yarn test*), Bash(pytest*), Bash(go test*), Bash(cargo test*), Read, Edit, Write, Glob, Grep, TodoWrite
---

Resolve merge conflicts for a PR end to end.

## Inputs

- Optional: PR URL or PR number.
- If missing, infer PR from current branch.

## Workflow

1. Create a `TodoWrite` list.
2. Validate prerequisites:
   - `git rev-parse --is-inside-work-tree`
   - `gh auth status`
   - Working tree must be clean before starting (`git status --porcelain`).
3. Identify target PR:
   - If user provided PR URL/number, use it.
   - Else:
     - `branch=$(git branch --show-current)`
     - `gh pr list --state open --head "$branch" --json number,url,title,updatedAt`
     - If none found, stop and ask user for PR URL/number.
     - If multiple found, choose the most recently updated.
4. Load PR metadata:
   - `gh pr view <pr> --json number,url,title,headRefName,baseRefName,headRepositoryOwner`
5. Check out PR branch locally:
   - Prefer `gh pr checkout <pr>`.
   - If already in an in-progress merge/rebase for this PR branch, continue instead of restarting.
6. Merge base into head to surface conflicts:
   - `git fetch origin <baseRefName>`
   - `git merge --no-ff --no-commit origin/<baseRefName>`
   - If merge completes cleanly, commit merge and finish.
7. If conflicts exist:
   - List conflicted files: `git diff --name-only --diff-filter=U`.
   - Resolve each file from first principles (do not blindly prefer ours/theirs).
   - Preserve intended behavior from both sides where possible.
   - `git add` each resolved file.
   - Verify no unresolved files remain.
8. Run relevant tests for changed/conflicted areas (targeted tests first).
9. Finish merge:
   - Ensure clean index except intended merge changes.
   - Create merge commit with default merge message unless user requested custom message.
10. Report:
   - PR used (explicit or inferred),
   - files resolved,
   - tests run and results,
   - any follow-up risk.

## Rules

- Do not use `git checkout --theirs` or `git checkout --ours` as a blanket strategy.
- Do not discard unrelated local changes.
- If conflict intent is ambiguous, stop and ask the user a focused question.
- Prefer minimal, behavior-preserving resolutions.
