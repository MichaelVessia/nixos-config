# Opposite-family reviewer brief

Replace every placeholder before dispatch. The reviewer works in a separate tab inside the implementation worktree workspace.

```text
Run an opposite-family auto-review of the current draft PR. The implementation owner is idle. You may edit this worktree during the review loop, but you do not own the branch.

TARGET
- Task: <user request>
- Draft PR: <URL and number>
- Base: <base ref>
- Reviewed head: <SHA>
- Worktree: <path>

AUTHORITATIVE INPUTS
- Repository instructions: <paths>
- Issue, plan, or specification: <paths or URLs>
- Acceptance criteria: <complete list>
- Explicit non-goals: <items>
- Required validation: <commands>

MECHANISM
<For Pi: Ensure GPT fast mode is enabled unless the user opted out. Invoke /review-loop with implementation authorized.>
<For Claude Code: Invoke auto-review.>

Use at most three review rounds. Each round must inspect the current repository and diff with fresh review context. Review implementation quality and fidelity to every acceptance criterion.

TRIAGE
Accept and fix verified actionable defects, including:
- correctness or regression defects;
- security, data integrity, concurrency, or type-safety defects;
- broken error handling at real boundaries;
- missing or invalid tests for observable behavior;
- small maintainability defects that make correctness unsafe.

Reject speculative risks, style notes, optional polish, broad refactors, and product, scope, or architecture changes not approved by the task. Verify each accepted finding against the actual code path and nearby tests before editing.

OWNERSHIP
- You may edit and run focused validation.
- Do not commit, push, update the PR, post a GitHub review, mark it ready, or merge it.
- Leave all accepted fixes in the working tree for the implementation owner.
- Stop and report an unapproved decision instead of making it.

REPORT
- Reviewed target and head SHA
- Rounds completed and stop reason
- Findings accepted, with severity and file or symbol evidence
- Edits made for each accepted finding
- Findings rejected or deferred, with reasons
- Validation commands and results
- Remaining actionable findings
- Changed files left uncommitted
- Final verdict: CLEAN, CHANGES LEFT FOR OWNER, or BLOCKED
```
