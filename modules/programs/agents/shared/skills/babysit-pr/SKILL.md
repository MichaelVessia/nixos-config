---
name: babysit-pr
description: |
  Babysit an already-open PR end to end: monitor CI + bot comments, invoke
  `fix-pr` on issues, then merge when clean (respecting repo branch
  protection). Composes `monitor-pr` + `merge-pr`. Use when user says
  "babysit", "babysit PR", "watch and merge", or wants hands-off ship-it
  behavior on an existing PR.
allowed-tools: Bash(gh *), Skill
---

# babysit-pr

Arguments: `$ARGUMENTS` (optional PR number or URL; else current branch PR).

This skill is a recipe: `monitor-pr` → `merge-pr`. All real work is delegated.

## 1) Monitor

Invoke `monitor-pr` with `$ARGUMENTS`.

- If it exits **clean**, proceed to step 2.
- If it exits **blocked**, stop. Print its report verbatim and exit. Do NOT
  merge.

## 2) Merge

Invoke `merge-pr` with `$ARGUMENTS`.

`merge-pr` enforces all policy (no CHANGES_REQUESTED bypass, uses repo's
allowed merge method, uses `gh pr merge --auto` to respect branch
protection).

## 3) Report

Combine the two sub-reports into a single final summary:

```
## Babysit-PR

- **PR**: <URL>
- **Monitor outcome**: clean | blocked (<reason>)
- **Merge outcome**: merged | queued (auto-merge) | not attempted | blocked (<reason>)
- **fix-pr invocations**: 0 | 1 | 2 | 3
```

If the PR was queued via auto-merge, tell the user it will land on its own
once branch protection clears.
