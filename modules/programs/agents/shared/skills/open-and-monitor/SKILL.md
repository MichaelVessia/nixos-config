---
name: open-and-monitor
description: |
  Open a draft PR, then watch CI and bot reviewers and autofix until clean.
  Use when user says "open and monitor", "ship it", "open PR and fix", or
  wants a hands-off PR workflow. Does NOT merge — use `babysit-pr` for an
  existing PR with auto-merge, or follow this with `merge-pr` once clean.
allowed-tools: Bash(gh *), Skill
---

# open-and-monitor

Arguments: `$ARGUMENTS` (passed through to `draft-pr`).

Recipe: `draft-pr` → `monitor-pr`. All real work is delegated.

## 1) Open draft PR

Invoke `draft-pr` with `$ARGUMENTS`. Capture the resulting PR number/URL:

```
gh pr view --json number,url --jq '.number, .url'
```

## 2) Monitor

Invoke `monitor-pr` with the PR number.

It handles the CI + bot-comment polling loop, invokes `fix-pr` on failures,
and exits either **clean** or **blocked**. Print its report verbatim as the
final output.

This skill does NOT merge. If you want auto-merge on an existing PR, use
`babysit-pr` instead.
