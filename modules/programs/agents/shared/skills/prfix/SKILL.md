---
name: prfix
description: |
  Autonomously fix a pull request by resolving relevant failing PR checks, then
  addressing PR comments one by one. Use when user says "prfix", "fix PR
  checks", "address PR feedback", or asks to clean up a PR end to end. For
  each accepted fix, commit and push. After comment fixes, invoke the
  gh-comment skill to post what changed.
allowed-tools: Bash(gh *), Bash(git *), Bash(npm test*), Bash(bun test*), Bash(pnpm test*), Bash(yarn test*), Read, Edit, Write, Glob, Grep, TodoWrite
---

# prfix

Arguments: `$ARGUMENTS` (optional PR number or URL).

Execute this flow fully, stop only if blocked.

## 1) Resolve target PR

1. Determine PR target:
   - If `$ARGUMENTS` has PR URL/number, use it.
   - Else use current branch PR: `gh pr view`.
2. Load PR context:
   - Number, URL, title, body, head ref, head SHA.
   - Changed files list from `gh pr diff --name-only`.

## 2) Fix relevant failing checks

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

## 3) Address PR comments

1. Gather comments:
   - PR conversation comments (`gh pr view --json comments,reviews`).
   - Inline review comments (`gh api repos/{owner}/{repo}/pulls/<PR>/comments --paginate`).
2. Create todo list with one item per comment (include author, file:line, body).
3. Process comments one by one. For each comment, evaluate:
   - Is the feedback correct?
   - Is it actionable and worth addressing now?
   - What exact change should be made?
4. If addressing:
   - Implement fix.
   - Run targeted tests/checks.
   - Commit and push.
   - Record short change summary for reply.
5. If not addressing:
   - Record concise rationale for reply.

## 4) Reply on PR via gh-comment skill

After each processed comment (or as a grouped batch), invoke `gh-comment` skill
to post a reply that includes:

- Comment reference (author + file:line when present)
- Decision (`addressed` or `not addressed`)
- What changed (commit SHA summary) or why skipped

Keep replies factual and brief.

## 5) Done criteria

Complete only when all are true:

- No relevant failing PR checks remain.
- Every gathered PR comment has been evaluated.
- Accepted comments have fixes committed and pushed.
- PR replies were posted through `gh-comment`.

If blocked (missing permissions, failing external service, ambiguous feedback),
stop and report exact blocker plus next required user action.
