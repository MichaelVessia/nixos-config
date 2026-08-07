# Implementation owner brief

Use the sections that apply. Replace every placeholder with source-grounded information before dispatch.

## Initial dispatch

```text
You own implementation and branch delivery for one draft PR in this Herdr-managed worktree.

TASK
<user request>

AUTHORITATIVE INPUTS
- Repository instructions: <paths>
- Issue, plan, or specification: <paths or URLs>
- Acceptance criteria: <complete list>
- Base branch: <ref>
- Branch: <name>
- Worktree: <path>

BOUNDARIES
- In scope: <items>
- Non-goals: <items>
- Decisions that require the user: <items>

VALIDATION
- Focused commands: <commands>
- Required repository commands: <commands>
- CI expectations: <checks or workflows>

DELIVERY
1. Read the repository instructions and authoritative inputs first.
2. Investigate the affected code and tests before choosing an implementation.
3. Implement only the approved scope and add tests for observable behavior.
4. Run focused local validation.
5. Commit with the repository's conventions and push the branch.
6. Open a DRAFT PR using the repository template.
7. Monitor CI for the current head. Diagnose, fix, validate, commit, and push relevant failures until green.
8. Retry a clearly transient external failure once. Report exact evidence if it persists.
9. Keep the PR draft. Do not merge or mark it ready for review.
10. When the current head is green, report the PR URL, head SHA, checks, tests, changed files, and residual risks. Then become idle so an opposite-family reviewer can use this worktree.

Work autonomously through the first green CI gate. Ask only for a product, scope, architecture, credential, or persistent external blocker that cannot be resolved from repository evidence.
```

## Review handback

```text
Resume branch ownership after the opposite-family review. The reviewer is now idle and may have left uncommitted edits.

REVIEW REPORT
<complete reviewer report>

CURRENT WORKTREE
- Status: <git status>
- Diff summary: <summary>
- Changed files: <files>

HANDOFF
1. Inspect every reviewer edit and its surrounding code.
2. Retain, correct, or revert each edit. Record an evidence-based reason for rejected findings or reverted edits.
3. Resolve remaining actionable defects that stay within approved scope.
4. Run focused validation and all required repository checks.
5. If your correction materially changes reviewed behavior, report that fact before committing so the controller can request a focused final review pass.
6. Commit and push accepted changes.
7. Update the draft PR body when behavior, tests, or residual risks changed.
8. Monitor CI until every required or relevant check for the new head is green.
9. Confirm the PR remains draft and conflict-free.

Do not merge or mark the PR ready for review. Finish with the final head SHA, CI rollup, tests, review dispositions, residual risks, and draft state.
```
