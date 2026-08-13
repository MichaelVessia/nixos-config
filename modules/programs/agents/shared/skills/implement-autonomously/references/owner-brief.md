# Owner brief

Fill only fields that affect this task. Give the owner paths and commands rather
than restating repository content it can read.

## Initial dispatch

```text
Own this task through a green draft PR in the current Herdr worktree.

TASK
<user request>

SOURCES
- Repository instructions: <paths>
- Issue, plan, or specification: <paths or URLs>
- Acceptance criteria: <complete list>
- Base and branch: <refs>

BOUNDARIES
- In scope: <items>
- Non-goals: <items>
- Decisions reserved for the user: <items>

VALIDATION
- Required commands: <commands>
- Behavior-level check: <representative workflow, or why none is practical>

DELIVERABLE
Implement the approved scope, test the changed behavior, commit, push, and open
a draft PR from the repository template. Keep the PR concise and include the
validation performed, useful evidence, verification gaps, and residual risks.
Repair relevant CI failures until the current head is green.

Operate autonomously. Pause only when the work requires an irreversible action,
a real scope decision, credentials, or input only the user can provide. Before
reporting progress or completion, check it against tool output. End only when the
head is green or a concrete blocker remains.

Report the PR URL, head SHA, checks, validation, changed files, and residual
risks. Then become idle so the reviewer can use the worktree.
```

## Review handback

```text
Resume branch ownership. The reviewer is idle and may have left uncommitted
changes.

REVIEW
<review report>

WORKTREE
- Status: <git status>
- Diff: <summary>

Inspect each reviewer edit. Keep, correct, or revert it based on the task and
code. Resolve remaining actionable findings, rerun affected validation, commit
and push accepted changes, update the draft PR when its description or evidence
is stale, and return the final head to green CI. If your correction materially
changes reviewed behavior, report that before committing so the controller can
request a focused final pass.

Finish with the final SHA, CI, validation, review dispositions, residual risks,
and confirmation that the PR remains draft.
```
