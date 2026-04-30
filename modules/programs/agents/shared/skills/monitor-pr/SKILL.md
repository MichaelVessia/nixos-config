---
name: monitor-pr
description: |
  Watch an open PR's CI and bot comments; on relevant failure or new bot
  feedback, invoke `fix-pr`. Exit when the PR is clean or stuck. Use when user
  says "monitor PR", "watch CI", or wants hands-off CI shepherding without a
  merge step.
allowed-tools: Bash(gh *), Bash(git *), Bash(sleep *), Skill
---

# monitor-pr

Arguments: `$ARGUMENTS` (optional PR number or URL; else current branch PR).

Execute fully, stop only if blocked or stuck past the attempt budget.

## 1) Resolve target PR

1. If `$ARGUMENTS` has a PR URL/number, use it. Else `gh pr view` on current
   branch.
2. Capture: number, URL, head SHA, head ref.
3. Abort if no PR found.

## 2) Monitor loop (fail-fast)

Poll checks + bot/reviewer comments together. Max 120 iterations, 60s apart
(~2h). On each iteration:

1. Check status rollup:
   ```
   gh pr view <PR> --json statusCheckRollup --jq '
     .statusCheckRollup[] | [.name, .status, .conclusion] | @tsv
   '
   ```
2. Bot comments + reviews since last iteration:
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
   - **Any check FAILED and relevant?** (use `gh pr diff --name-only` to decide
     relevance: touched files, lint, typecheck, build, tests tied to changed
     code.) Break, go to step 3.
   - **New bot comment appeared?** Break, go to step 3.
   - **Human review with CHANGES_REQUESTED?** Break, go to step 4 (blocked).
   - **All checks PASSED and no new bot comments?** Go to step 5 (clean).
   - **Checks still PENDING, nothing failed?** `sleep 60`, continue.
4. If 120 iterations pass with checks still pending, proceed to step 4
   (blocked: CI never finished).

## 3) Fix

Invoke `fix-pr` with the PR number. It handles failing checks, comments,
commits, pushes, replies.

After `fix-pr` returns, re-enter step 2. Max 3 total `fix-pr` invocations.
After the third attempt, proceed to step 4 regardless of outcome.

## 4) Blocked exit

Output:

```
## Monitor-PR: blocked

- **PR**: <URL>
- **Reason**: <changes-requested | CI-stuck | fix-pr-budget-exhausted | other>
- **Failing checks**: <list or none>
- **Open bot comments**: <count>
- **Human reviews**: <state>
- **Next step**: <what the user needs to do>
```

Exit non-clean. Do not merge.

## 5) Clean exit

Output:

```
## Monitor-PR: clean

- **PR**: <URL>
- **Checks**: all passed
- **Bot comments**: addressed
- **fix-pr invocations**: 0 | 1 | 2 | 3
- **Ready to merge**: yes
```

Caller may now invoke `merge-pr`. This skill does NOT merge.
