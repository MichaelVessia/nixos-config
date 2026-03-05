---
name: open-and-monitor
description: |
  Open a draft PR, wait for CI and bot reviewers to finish, then fix
  everything autonomously. Use when user says "open and monitor", "ship it",
  "open PR and fix", or wants a hands-off PR workflow.
allowed-tools: Bash(gh *), Bash(git *), Bash(sleep *), Skill
---

# open-and-monitor

Arguments: `$ARGUMENTS` (passed through to `draft-pr`).

Execute this flow fully, stop only if blocked.

## 1) Open draft PR

1. Invoke `draft-pr` with `$ARGUMENTS`.
2. Capture the PR number and URL:
   ```
   gh pr view --json number,url --jq '.number, .url'
   ```

## 2) Monitor checks and bot comments (fail-fast loop)

Poll checks and bot comments together. Max 40 iterations, 30s apart (~20 min).
On each iteration:

1. Query check status:
   ```
   gh pr view <PR> --json statusCheckRollup --jq '
     .statusCheckRollup[] | [.name, .status, .conclusion] | @tsv
   '
   ```
2. Query bot comments:
   ```
   gh pr view <PR> --json comments,reviews --jq '
     [.comments[], .reviews[]]
     | map(select(
         .author.is_bot == true
         or (.author.login | test("bot|copilot|dependabot|renovate|coderabbit"; "i"))
       ))
     | length
   '
   ```
3. Evaluate:
   - **Any check FAILED?** Get the changed files list (`gh pr diff --name-only`)
     and determine if the failure is relevant to PR changes (touched files,
     tests, lint, typecheck, build, or logic connected to changed code). If
     relevant, break out of the loop immediately and go to step 3.
   - **Bot comments appeared?** Break out immediately and go to step 3.
   - **All checks PASSED and no bot comments?** Skip to step 5.
   - **Checks still PENDING, nothing failed yet?** `sleep 30` and continue
     polling.
4. If 40 iterations pass with checks still pending, proceed to step 3 with
   whatever state exists.

## 3) Fix

Invoke `fix-pr`. It handles failing checks, bot/reviewer comments, commits,
pushes, and replies.

## 4) Verify fixes

After `fix-pr` completes, re-enter the monitoring loop from step 2 (same
fail-fast logic). If a relevant failure or new bot comment appears again,
invoke `fix-pr` one more time (max 2 total invocations). After the second
attempt, proceed to step 5 regardless of outcome.

## 5) Final report

Output a summary:

```
## PR Summary

- **PR**: <URL>
- **Checks**: passed | failed
- **Bot comments**: <count>
- **fix-pr invocations**: 0 | 1 | 2
- **Status**: clean | needs attention
```

If checks are still failing after 2 fix-pr attempts, list the remaining
failures and recommend next steps.
