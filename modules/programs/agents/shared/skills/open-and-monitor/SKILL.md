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

## 2) Wait for CI checks

1. Wait for all checks to complete:
   ```
   gh pr checks <PR> --watch --interval 30
   ```
2. Record whether checks passed or failed.

## 3) Wait for bot comments

Poll for bot-authored comments/reviews (max 10 iterations, 30s apart).

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

- If count > 0, stop polling early.
- If count is still 0 after 10 iterations, proceed anyway.

## 4) Decide next action

- If CI failed OR bot comments exist: invoke `fix-pr`.
- If CI passed AND no bot comments: skip to step 6.

## 5) Verify fixes

After `fix-pr` completes, re-run `gh pr checks <PR> --watch --interval 30`.

- If checks still fail, invoke `fix-pr` one more time (max 2 total invocations).
- After the second attempt, proceed to step 6 regardless of outcome.

## 6) Final report

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
