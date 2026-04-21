---
name: merge-pr
description: |
  Merge an open PR if (and only if) repo policy allows: CI green, no
  CHANGES_REQUESTED review, branch protection satisfied. Uses `gh pr merge
  --auto` with the repo's allowed merge method. Never bypasses protection.
  Use when user says "merge PR", "merge it", or after `monitor-pr` exits clean.
allowed-tools: Bash(gh *), Bash(git *), Skill
---

# merge-pr

Arguments: `$ARGUMENTS` (optional PR number or URL; else current branch PR).

Never bypass branch protection. Never use `--admin`. Never force.

## 1) Resolve target PR

1. If `$ARGUMENTS` has PR URL/number, use it. Else `gh pr view`.
2. Capture: number, URL, state, isDraft, reviewDecision, mergeable,
   mergeStateStatus:
   ```
   gh pr view <PR> --json number,url,state,isDraft,reviewDecision,mergeable,mergeStateStatus,statusCheckRollup,baseRefName,headRefOid
   ```
3. Abort if: PR not found, state != OPEN, or isDraft == true (report and stop;
   do not mark ready for review automatically).

## 2) Pre-merge gate

Refuse to merge when any of the following is true. Report reason and exit.

- `reviewDecision == "CHANGES_REQUESTED"` — human asked for changes. **Never
  bypass.**
- Any required check has `conclusion` of `FAILURE`, `CANCELLED`, `TIMED_OUT`,
  or `ACTION_REQUIRED`.
- `mergeable == "CONFLICTING"` — resolve conflicts first (suggest
  `resolve-merge-conflicts`).
- `mergeStateStatus == "DIRTY"` — same as above.
- `mergeStateStatus == "BLOCKED"` AND reason is anything other than pending
  required checks (branch protection is actively blocking, e.g. missing
  required review). `gh pr merge --auto` will still queue this, but only if
  the only blocker is pending checks. When `BLOCKED` is due to missing
  approvals, exit and report "waiting on required approval" — let the human
  decide.

If `mergeStateStatus == "BEHIND"`, suggest the caller update the branch
first; do not auto-update unless the repo's default is `gh pr merge --auto`
with update-branch (detect via `gh api repos/{owner}/{repo}` if needed).

## 3) Detect merge method

Query repo settings:

```
gh api repos/{owner}/{repo} --jq '{
  squash: .allow_squash_merge,
  merge: .allow_merge_commit,
  rebase: .allow_rebase_merge
}'
```

Pick the first enabled method in this order: `squash`, `merge`, `rebase`.
If none are enabled (shouldn't happen), abort and report.

## 4) Merge

Use `--auto` so branch protection enforces approvals + required checks. If the
PR is already fully green and approved, `--auto` merges immediately; otherwise
GitHub queues it until protection is satisfied.

```
gh pr merge <PR> --auto --<method> --delete-branch
```

- `--delete-branch` removes the head branch after merge (standard hygiene).
  If the repo disables branch deletion or the branch is protected, `gh` will
  ignore or warn; that's fine.

If `gh pr merge --auto` fails because auto-merge is disabled on the repo,
fall back to a direct merge only if all gates in step 2 are satisfied right
now:

```
gh pr merge <PR> --<method> --delete-branch
```

Never pass `--admin`.

## 5) Report

```
## Merge-PR

- **PR**: <URL>
- **Method**: squash | merge | rebase
- **Outcome**: merged | queued (auto-merge) | blocked
- **Reason** (if blocked): <changes-requested | conflicts | failing-checks | missing-approval | other>
```

If queued via `--auto`, tell the user the merge will happen automatically once
protection gates clear; they don't need to do anything.
