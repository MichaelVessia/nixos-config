---
name: implement-autonomously
description: Implement one task autonomously through a Herdr worktree, draft PR, green CI, opposite-family review, and final human handoff.
compatibility: Requires Herdr, git, GitHub CLI, and Pi with claude-bridge models, GPT-5.6 Sol, GPT fast mode, and pi-subagents.
disable-model-invocation: true
---

# Implement autonomously

Implement one task until its draft PR is safe for the user to inspect. The controller owns the state machine. The implementation agent owns the branch. Pi runs every agent session. The opposite model family reviews after the first green CI result.

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
## 1. Select the models

Use the implementation model in the invocation when it is explicit. Otherwise ask the user to select one pairing before creating anything:

1. Pi with `claude-bridge/claude-fable-5` implements. Pi with `openai-codex/gpt-5.6-sol` reviews.
2. Pi with `openai-codex/gpt-5.6-sol` implements. Pi with `claude-bridge/claude-fable-5` reviews.

Ask: `Which model should implement: (1) Claude Fable 5, or (2) GPT-5.6 Sol? Pi runs both roles, and the other model family will review.`

There is no default pairing. Use GPT fast mode for GPT-5.6 Sol unless the user opts out. Preserve any explicit thinking level. Always launch Pi, including for `claude-bridge/*` models. Do not launch Claude Code or substitute another model when a required model is unavailable.

**Complete when:** the Pi implementer and opposite-family Pi reviewer models are explicit.

## 2. Establish control and evidence

If `HERDR_ENV=1`, read and follow `../herdr/SKILL.md`. Otherwise read and follow `../herdr-dispatch/SKILL.md`; this explicit skill invocation authorizes external Herdr control. For this workflow, the Pi-only routing in this skill overrides the dispatch adapter's generic routing for unqualified Claude model names. A full `claude-bridge/*` identifier always runs through `--kind pi`.

Verify:

- Herdr connectivity and the current repository workspace;
- repository root, default or requested base branch, and worktree path policy;
- `git`, `gh`, and GitHub authentication;
- both required models in Pi;
- the exact Pi launch form `herdr agent start <name> --kind pi --pane <pane-id> -- --model <provider/model>` for every role;
- Pi's review loop for both model families;
- GPT fast mode for GPT-5.6 Sol and `pi-subagents` for every role;
- the repository instructions, task source, acceptance criteria, PR template, and validation commands.

Define an end-to-end verification plan before dispatch. Choose proof that matches the user-visible or system-visible behavior. Examples include:

- browser screenshots or a short recording for a user interface flow;
- request and response evidence for an API flow;
- terminal output for a command-line flow;
- deployment, service, log, or metric evidence for an infrastructure change;
- before-and-after output for a bug fix or behavior change.

Prefer a real workflow over an isolated function call. Use the safest representative environment and data. Record the expected artifact, where it will be stored, and how it will appear in the PR description. If true end-to-end verification is not possible, require the strongest available substitute and a specific explanation of the missing verification, its cause, and the manual steps a human can run.

Maintain this run record in the controller context:

| Worktree workspace | Path | Branch | Implementer model | Implementer launch | Reviewer model | Reviewer launch | Draft PR | Head SHA | CI 1 | Review | CI 2 | Blocker |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

For each role, record controller-visible evidence that Herdr launched Pi with the selected full provider/model identifier.

**Complete when:** every field needed for dispatch is known, and no prerequisite is assumed.

## 3. Create the worktree and implementation owner

Use `herdr worktree create` under the current repository workspace. Pass the base, branch, path, label, and `--no-focus` explicitly. Never replace this with manual `git worktree` commands or a normal Herdr tab.

Start the selected implementer in the worktree's root pane with Pi and the full provider/model identifier:

```bash
herdr agent start <implementer-name> \
  --kind pi \
  --pane <worktree-root-pane-id> \
  -- --model <provider/model>
```

Use `claude-bridge/claude-fable-5` or `openai-codex/gpt-5.6-sol` according to the selected pairing. Preserve an explicit Pi thinking level in the launch arguments. Before dispatch, verify the actual launch arguments from controller-visible command or process evidence. If Pi or the model is wrong, do not send the task. Terminate that session with Herdr key controls, verify that its pane returned to a shell, then start and verify a correctly configured replacement.

When GPT-5.6 Sol implements, ensure fast mode is enabled before dispatch unless the user opted out. Prepare a source-grounded prompt from [the owner brief](references/owner-brief.md). Include the task, acceptance criteria, governing plans or issues, repository rules, validation commands, non-goals, branch details, and autonomy boundary.

Submit without a synchronous wait. Use the active Herdr adapter's wake mechanism to resume when the owner becomes idle, done, or blocked. Read the full handoff after each wake. Give routine implementation and CI repairs back to the same owner.

**Complete when:** one Pi implementation owner is working in the tracked worktree with a complete brief and verified model launch evidence.

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

Start the reviewer with Pi and the selected opposite-family model:

```bash
herdr agent start <reviewer-name> \
  --kind pi \
  --pane <reviewer-tab-root-pane-id> \
  -- --model <provider/model>
```

Verify Pi and the full provider/model launch arguments before sending the review task. If either is wrong, do not prompt or use that reviewer session. Terminate it with Herdr key controls, verify that its pane returned to a shell, then start and verify a correctly configured replacement.

Prepare its task from [the reviewer brief](references/reviewer-brief.md). Give it the same task, plan, acceptance criteria, base, PR, repository rules, and validation contract as the implementer.

Use Pi's `/review-loop` with implementation authorized. Enable GPT fast mode when the reviewer is GPT-5.6 Sol unless the user opted out.

The review uses fresh context, evidence-backed triage, accepted edits, and re-review until clean or capped at three rounds. The reviewer may edit the worktree only while the implementer is idle. It leaves all changes uncommitted and unpushed.

Read the complete review report and inspect the worktree after the reviewer becomes idle. Record accepted fixes, rejected findings, validation, remaining findings, and the stop reason. Also record whether the reviewer found the end-to-end proof relevant, readable, and consistent with the implementation. The reviewer does not update the PR.

**Complete when:** the Pi reviewer is idle, its loop is clean or capped, all edits and remaining findings are accounted for, and its model launch evidence is verified.

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
- every agent used in the run has controller-visible evidence for Pi and the selected model;
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
- Implementer: <Pi model and mode>
- Reviewer: <Pi model and mode>
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
