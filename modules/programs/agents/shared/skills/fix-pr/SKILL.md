---
name: fix-pr
description: |
  Autonomously fix a pull request by resolving relevant failing PR checks, then
  addressing PR comments and posting replies. Use when user says "fix pr",
  "prfix", "fix PR checks", "address PR feedback", or asks to clean up a PR
  end to end.
allowed-tools: Bash(gh *), Bash(git *), Bash(npm test*), Bash(bun test*), Bash(pnpm test*), Bash(yarn test*), Read, Edit, Write, Glob, Grep, TodoWrite, Skill
---

# fix-pr

Arguments: `$ARGUMENTS` (optional PR number or URL).

Execute this flow fully, stop only if blocked.

## 1) Resolve target PR

1. Determine PR target:
   - If `$ARGUMENTS` has PR URL/number, use it.
   - Else use current branch PR: `gh pr view`.
2. Load PR context:
   - Number, URL, title, body, head ref, head SHA.
   - Changed files list from `gh pr diff --name-only`.

## 2) Resolve merge conflicts

1. Check if the PR has merge conflicts:
   - Use `gh pr view <PR> --json mergeable,mergeStateStatus`.
2. If conflicts exist, invoke `resolve-merge-conflicts` with the PR number.
3. After resolution, push and confirm the PR is conflict-free before proceeding.

## 3) Fix relevant failing checks

1. Inspect checks for this PR:
   - Use `gh pr view <PR> --json statusCheckRollup`.
   - Also inspect recent workflow runs for PR head SHA with `gh run list` and
     details via `gh run view --log-failed`.
2. Build todo list of failing checks.
3. For each failing check:
   - Decide relevance to PR changes.
   - Relevant when failure points to touched files, tests, lint, typecheck,
     build, or logic connected to changed code.
   - Ignore clearly unrelated infra flakes (document why).
4. For each relevant failure:
   - Reproduce locally when possible.
   - Implement fix from first principles.
   - Run targeted tests/checks for changed area.
   - Commit and push immediately after passing checks.
   - Use clear commit message, no AI attribution text.
5. Re-query PR checks. Continue until no relevant failures remain.

## 4) Address PR comments

Invoke `address-pr-feedback` to review and address all open PR comments. The
skill handles gathering comments, creating a todo list, implementing fixes,
running tests, and committing changes.

## 5) Reply on PR via gh-comment

After `address-pr-feedback` completes, invoke `gh-comment` to post replies for
each processed comment. Include:

- Comment reference (author + file:line when present)
- Decision (`addressed` or `not addressed`)
- What changed (commit SHA summary) or why skipped

Keep replies factual and brief.

## 6) Done criteria

Complete only when all are true:

- PR has no merge conflicts.
- No relevant failing PR checks remain.
- Every gathered PR comment has been evaluated.
- Accepted comments have fixes committed and pushed.
- PR replies were posted through `gh-comment`.

If blocked (missing permissions, failing external service, ambiguous feedback),
stop and report exact blocker plus next required user action.
