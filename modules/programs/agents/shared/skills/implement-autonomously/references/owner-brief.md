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
- End-to-end flow: <representative user-visible or system-visible workflow>
- Proof artifact: <screenshot, recording, request and response, terminal output, deployment evidence, or other task-appropriate proof>
- Proof location: <durable GitHub-viewable location>
- Safe environment and data: <details>

DELIVERY
1. Read the repository instructions and authoritative inputs first.
2. Investigate the affected code and tests before choosing an implementation.
3. Implement only the approved scope and add tests for observable behavior.
4. Run focused local validation.
5. Run the planned end-to-end flow in a safe representative environment. Capture proof of the result.
6. Commit with the repository's conventions and push the branch.
7. Open a DRAFT PR using the repository template.
8. Add an `End-to-end verification` section to the PR description. Keep all required template sections.
9. In that section, state the environment, steps, expected result, actual result, and proof. Embed or link proof that a reviewer can open from GitHub. A local file path is not enough.
10. Write the full PR description with ASD-STE100 Simplified Technical English principles. Use short, direct sentences, active voice, common words, and one claim per sentence. Define necessary acronyms. Avoid vague statements such as "works as expected."
11. Do not expose secrets, personal data, access tokens, or unsafe production data in the proof.
12. If true end-to-end verification is not possible, use the strongest available substitute. In the PR description, state the exact cause, the unverified behavior, and the manual steps a human can run.
13. Monitor CI for the current head. Diagnose, fix, validate, commit, and push relevant failures until green.
14. Retry a clearly transient external failure once. Report exact evidence if it persists.
15. Keep the PR draft. Do not merge or mark it ready for review.
16. When the current head is green, report the PR URL, head SHA, checks, tests, proof, changed files, and residual risks. Then become idle so an opposite-family reviewer can use this worktree.

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
5. Repeat the end-to-end flow when your changes can affect the proved behavior. Replace stale proof.
6. If your correction materially changes reviewed behavior, report that fact before committing so the controller can request a focused final review pass.
7. Commit and push accepted changes.
8. Update the draft PR description when behavior, tests, proof, verification limits, or residual risks changed.
9. Keep the `End-to-end verification` section complete and human-readable. Apply ASD-STE100 principles to the full PR description.
10. Monitor CI until every required or relevant check for the new head is green.
11. Confirm the PR remains draft and conflict-free.

Do not merge or mark the PR ready for review. Finish with the final head SHA, CI rollup, tests, end-to-end proof, review dispositions, residual risks, and draft state.
```
