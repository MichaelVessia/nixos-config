---
name: implement-autonomously
description: Implement one task autonomously through a Herdr worktree, draft PR, green CI, opposite-family review, and final human handoff.
compatibility: Requires Herdr, git, GitHub CLI, Claude Code with Fable and auto-review, and Pi with GPT-5.6 Sol, GPT fast mode, and pi-subagents.
disable-model-invocation: true
---

# Implement autonomously

Implement one task until its draft PR is safe for the user to inspect. The controller owns the state machine. The implementation agent owns the branch. The opposite model family reviews after the first green CI result.

## Guardrails

- Keep the PR draft. A human-ready result is not GitHub's Ready for review state.
- Never merge the PR.
- Use one Herdr-managed worktree for the full run.
- Give the implementer and reviewer separate tabs in that worktree workspace.
- Keep only one agent writing at a time.
- Let the reviewer edit, but not commit, push, or update the PR. Return branch ownership to the implementer after review.
- Continue through waits and repair cycles. Stop only for a user decision, missing credentials, unavailable required agent, persistent external failure, or the final handoff.
- Verify state from Herdr, git, and GitHub. An agent's report is not evidence by itself.
- Always attempt task-level end-to-end verification. Unit tests, lint, type checks, and CI support this verification, but they do not replace it.
- Put human-reviewable proof in the PR description. Do not leave proof only in an agent report, a local file, or a CI log.
- Write the PR description with ASD-STE100 Simplified Technical English principles. Use short, direct sentences, active voice, common words, and one instruction or claim per sentence. Define necessary acronyms and avoid vague claims.
- Never expose secrets, personal data, access tokens, or unsafe production data in proof artifacts.
- Start every Claude Code session, including every Fable implementer or reviewer, with the exact `--dangerously-skip-permissions` flag. This requirement has no opt-out in this skill.
- Pass `--dangerously-skip-permissions` to Claude Code after the `herdr agent start` `--` separator. Never rely on an alias, saved setting, inherited session, or default permission mode.
- Never send a task prompt to a Claude Code session until the controller verifies that the launch arguments contain `--dangerously-skip-permissions`.

## 1. Select the crew

Use the implementation choice in the invocation when it is explicit. Otherwise ask the user to select one crew before creating anything:

1. Claude Code with Fable implements. Pi with `openai-codex/gpt-5.6-sol` reviews.
2. Pi with `openai-codex/gpt-5.6-sol` implements. Claude Code with Fable reviews.

Ask: `Who should implement: (1) Claude Code with Fable, or (2) Pi with GPT-5.6 Sol? The other family will review.`

There is no default crew. Use GPT fast mode whenever Pi participates unless the user opts out. Preserve any explicit effort or thinking level. Do not substitute another harness or model when a required profile is unavailable.

**Complete when:** the implementer and opposite-family reviewer profiles are explicit.

## 2. Establish control and evidence

If `HERDR_ENV=1`, read and follow `../herdr/SKILL.md`. Otherwise read and follow `../herdr-dispatch/SKILL.md`; this explicit skill invocation authorizes external Herdr control.

Verify:

- Herdr connectivity and the current repository workspace;
- repository root, default or requested base branch, and worktree path policy;
- `git`, `gh`, and GitHub authentication;
- both required agent profiles;
- the exact Claude Code launch form `herdr agent start <name> --kind claude --pane <pane-id> -- --model fable --dangerously-skip-permissions` for every Fable role, with `--effort <level>` added before the permission flag when needed;
- Claude Code `auto-review` when Claude reviews;
- Pi fast mode and `pi-subagents` when Pi participates;
- the repository instructions, task source, acceptance criteria, PR template, and validation commands.

Define an end-to-end verification plan before dispatch. Choose proof that matches the user-visible or system-visible behavior. Examples include:

- browser screenshots or a short recording for a user interface flow;
- request and response evidence for an API flow;
- terminal output for a command-line flow;
- deployment, service, log, or metric evidence for an infrastructure change;
- before-and-after output for a bug fix or behavior change.

Prefer a real workflow over an isolated function call. Use the safest representative environment and data. Record the expected artifact, where it will be stored, and how it will appear in the PR description. If true end-to-end verification is not possible, require the strongest available substitute and a specific explanation of the missing verification, its cause, and the manual steps a human can run.

Maintain this run record in the controller context:

| Worktree workspace | Path | Branch | Implementer | Implementer launch | Reviewer | Reviewer launch | Draft PR | Head SHA | CI 1 | Review | CI 2 | Blocker |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

For each Claude Code role, record controller-visible evidence that its launch arguments included `--dangerously-skip-permissions`. Record `not applicable` for Pi roles.

**Complete when:** every field needed for dispatch is known, and no prerequisite is assumed.

## 3. Create the worktree and implementation owner

Use `herdr worktree create` under the current repository workspace. Pass the base, branch, path, label, and `--no-focus` explicitly. Never replace this with manual `git worktree` commands or a normal Herdr tab.

Start the selected implementer in the worktree's root pane. If Claude Code with Fable implements, use this launch shape and include the flag literally:

```bash
herdr agent start <implementer-name> \
  --kind claude \
  --pane <worktree-root-pane-id> \
  -- --model fable --dangerously-skip-permissions
```

When an effort level is explicit, add `--effort <level>` after `--model fable` and before the permission flag. Do not put the permission flag before the `--` separator. Before dispatch, verify the actual launch arguments from controller-visible command or process evidence. A Claude agent's statement about its permission mode is not evidence. If the flag is missing, do not send the task. Terminate that session with Herdr key controls, verify that its pane returned to a shell, then start and verify a correctly configured replacement. Do not continue by answering permission prompts.

If Pi implements, ensure fast mode is enabled before dispatch unless the user opted out. Prepare a source-grounded prompt from [the owner brief](references/owner-brief.md). Include the task, acceptance criteria, governing plans or issues, repository rules, validation commands, non-goals, branch details, and autonomy boundary.

Submit without a synchronous wait. Use the active Herdr adapter's wake mechanism to resume when the owner becomes idle, done, or blocked. Read the full handoff after each wake. Give routine implementation and CI repairs back to the same owner.

**Complete when:** one implementation owner is working in the tracked worktree with a complete brief, and any Claude Code owner has verified `--dangerously-skip-permissions` launch evidence.

## 4. Reach the first green draft

The implementer must:

1. implement the approved scope;
2. run focused local validation;
3. run the planned end-to-end verification and capture task-appropriate proof;
4. commit and push the branch;
5. open a draft PR from the repository template;
6. add a clear `End-to-end verification` section to the PR description, without removing required template sections;
7. embed or link durable proof that a reviewer can open from GitHub, and state the tested environment, steps, and result;
8. repair relevant CI failures until the current head is green;
9. report the PR, head SHA, checks, tests, proof, and any residual risk;
10. become idle before review starts.

Screenshots must show the relevant final state and enough context to identify the tested flow. Text proof must include the command or action and the important result. A local path is not proof for a PR reviewer. Do not add generated proof files to the repository only to make them durable unless repository policy permits it. If no safe durable upload method is available, state that blocker and give exact reproduction steps in the PR description.

The controller must independently verify the PR URL, draft state, current head SHA, and check rollup. Green means every required or relevant check for that exact head completed successfully. Retry a clearly transient external failure once. Route code, test, lint, type, build, or migration failures to the implementer.

**Complete when:** the PR is draft, the implementer is idle, CI is green for the verified current head SHA, and the PR description contains task-appropriate end-to-end proof or a documented verification gap.

## 5. Run opposite-family auto-review

Create a new non-focused tab inside the existing worktree workspace, rooted at the same worktree path. This is a tab, not another worktree. Start the selected opposite-family reviewer there.

If Claude Code with Fable reviews, use this launch shape and include the flag literally:

```bash
herdr agent start <reviewer-name> \
  --kind claude \
  --pane <reviewer-tab-root-pane-id> \
  -- --model fable --dangerously-skip-permissions
```

When an effort level is explicit, add `--effort <level>` after `--model fable` and before the permission flag. Verify the launch arguments before sending the review task. If the flag is missing, do not prompt or use that reviewer session. Terminate it with Herdr key controls, verify that its pane returned to a shell, then start and verify a correctly configured replacement.

Prepare its task from [the reviewer brief](references/reviewer-brief.md). Give it the same task, plan, acceptance criteria, base, PR, repository rules, and validation contract as the implementer.

Use the reviewer's native mechanism:

- Pi: enable fast mode unless opted out, then use `/review-loop` with implementation authorized.
- Claude Code: use `auto-review`.

Both paths use the same contract: fresh review context, evidence-backed triage, accepted edits, and re-review until clean or capped at three rounds. The reviewer may edit the worktree only while the implementer is idle. It leaves all changes uncommitted and unpushed.

Read the complete review report and inspect the worktree after the reviewer becomes idle. Record accepted fixes, rejected findings, validation, remaining findings, and the stop reason. Also record whether the reviewer found the end-to-end proof relevant, readable, and consistent with the implementation. The reviewer does not update the PR.

**Complete when:** the reviewer is idle, its loop is clean or capped, all edits and remaining findings are accounted for, and any Claude Code reviewer has verified `--dangerously-skip-permissions` launch evidence.

## 6. Return ownership to the implementer

Send the existing implementer the review report and current worktree state using the handback section of [the owner brief](references/owner-brief.md). The implementer must:

1. inspect every reviewer edit;
2. retain, correct, or revert it with an evidence-based reason;
3. resolve remaining actionable defects within scope;
4. run focused and repository-required validation;
5. commit and push accepted changes;
6. repeat end-to-end verification when a change can affect the proved behavior;
7. update the draft PR description when behavior, evidence, verification limits, or residual risk changed;
8. keep the PR description human-readable and consistent with ASD-STE100 principles;
9. repair CI until the new current head is green.

If the implementer materially changes reviewed behavior while correcting reviewer work, return the stable diff to the same reviewer tab for a focused final pass before the last push and CI gate. Keep the implementer idle during that pass.

**Complete when:** the worktree is clean, accepted changes are pushed, review findings are resolved or explicitly rejected, end-to-end proof matches the final behavior, and CI is green for the final head SHA.

## 7. Hand off to the user

Verify directly:

- PR URL and number;
- final head SHA;
- PR remains draft;
- mergeability reports no conflict;
- every required or relevant check for the final head is successful;
- worktree is clean;
- both Herdr agents are idle;
- every Claude Code agent used in the run has controller-visible launch evidence for `--dangerously-skip-permissions`;
- no unresolved actionable review finding remains;
- the PR description has an `End-to-end verification` section;
- its proof is safe, durable, viewable from GitHub, and matches the final head;
- any verification gap has a specific reason, the strongest substitute evidence, and exact manual steps.

Read the final PR description directly. Do not accept the implementer's summary as proof that it is clear or complete.

Report:

```markdown
## Draft PR ready for your review

- PR: <URL> (#<number>)
- Final head: <SHA>
- Implementer: <harness, model, mode>
- Reviewer: <harness, model, mode>
- CI: <checks and conclusions>
- Local validation: <commands and results>
- End-to-end proof: <PR description section and linked or embedded artifacts>
- Verification gaps: <reason and manual steps, or none>
- Review: <rounds, findings, fixes, rejected findings>
- Residual risks: <items or none>
- Herdr: <worktree workspace and agent handles>
- State: Draft, not merged, ready for your inspection
```

Leave the worktree, tabs, branch, and draft PR in place.

**Complete when:** the user has a tool-verified final report and no human action occurred before it was needed.
