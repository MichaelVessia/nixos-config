---
name: implement-autonomously
description: Implement one task autonomously through a Herdr worktree, draft PR, green CI, optional opposite-family review, and final human handoff.
compatibility: Requires Herdr, git, GitHub CLI, and Pi with claude-bridge/openai-codex
disable-model-invocation: true
---

# Implement autonomously

Deliver one task as a green draft PR in a Herdr-managed worktree. An optional
opposite-family reviewer provides a higher-assurance path.

## Invariants

- The PR stays draft and unmerged.
- When review is enabled, the owner and reviewer use separate Pi sessions in the
  same worktree. Only one writes at a time.
- The owner alone commits, pushes, and edits the PR.
- Pause only for an irreversible action, a scope decision, unavailable access,
  or a persistent external failure.

## 1. Fix the profile and review policy

Use an explicit user choice from available Pi models. Otherwise use:

| Role     | Model                          | Thinking | Extra mode |
| -------- | ------------------------------ | -------- | ---------- |
| Owner    | `openai-codex/gpt-5.6-sol`    | `high`   | none       |
| Reviewer | `claude-bridge/claude-opus-5` | `high`   | none       |

When cross-family review selects a Claude-family reviewer, default to
`claude-bridge/claude-opus-5`. Use Fable only when the user explicitly requests
it. Preserve an explicit user model choice.

Default to cross-family review. The user may select `no cross-family review` for
a token-constrained run; then no reviewer session is created. They may also swap
models or override thinking. GPT fast mode is opt-in only when the user requests
it. Every selected model runs through Pi with `--kind pi`.

**Complete when:** the owner profile and review policy are explicit, and the
reviewer profile is explicit when review is enabled.

## 2. Dispatch the owner

Read `../herdr-dispatch/SKILL.md` for worktree and agent lifecycle. When
`HERDR_ENV=1`, also read `../herdr/SKILL.md` for in-session pane operations. The
Pi profiles above override generic model routing in those adapters.

Verify Herdr, `git`, `gh`, GitHub authentication, repository instructions, task
source, acceptance criteria, and base branch. Create one Herdr worktree. Start
Pi in its root pane with the owner profile and verify the actual launch:

```bash
herdr agent start <owner> \
  --kind pi \
  --pane <root-pane> \
  -- --model <provider/model> --thinking <level>
```

Read [references/owner-brief.md](references/owner-brief.md), fill its applicable
fields, and send it asynchronously. Use the adapter's wake mechanism. Keep this
owner through implementation, CI repair, and any review handback.

Ground each progress decision in Herdr, git, GitHub, or validation output. If
the owner ends on intent while reversible work remains, send it back to finish.

**Complete when:** the verified owner is working in the tracked worktree with a
source-grounded brief.

## 3. Reach the first green draft

Let the owner implement, validate, commit, push, open a draft PR, and repair
relevant CI failures. When it becomes idle, verify the PR directly:

- draft state and reported head SHA;
- required and relevant checks are green for that SHA;
- description covers the change, validation, gaps, and residual risks;
- behavior-level evidence exists when practical.

Return code and CI failures to the same owner. Retry one clearly transient
external failure.

**Complete when:** the verified head is green, the PR is draft, and the owner is
idle.

## 4. Review from fresh context when enabled

With `no cross-family review`, skip to Step 6 after confirming the Step 3 gate.
Otherwise create a new Pi session in a separate tab at the same worktree. Launch
and verify the reviewer profile. Inspect the review skills available to that
session. Prefer a repository-specific or task-specific review skill when one is
present. Otherwise use the best matching generic review skill. If no review
skill is available, follow the reviewer brief directly. Read
[references/reviewer-brief.md](references/reviewer-brief.md), fill its fields,
including the selected review skill, and send it asynchronously.

The reviewer uses the selected skill to inspect and test the change directly.
It may leave fixes in the working tree while the owner is idle. It does not
commit or change GitHub.

When review finishes, inspect the report and diff. Give every finding and edit
an explicit disposition before returning ownership.

**Complete when:** the reviewer is idle and every finding and edit is recorded
as accepted, rejected with evidence, or blocked.

## 5. Return ownership and close the review loop

This step applies only when review is enabled. Send the review report and diff
to the existing owner using the owner brief's handback. The owner resolves
findings, validates affected behavior, commits, pushes, updates the draft PR,
and restores green CI.

If this materially changes reviewed behavior, launch a fresh reviewer session
for a focused pass, then repeat the handback.

**Complete when:** every review item has a final disposition, the worktree is
clean, the final PR evidence matches the final SHA, and relevant CI is green for
that SHA.

## 6. Hand off

Verify the final PR URL and SHA, draft state, mergeability, checks, clean
worktree, idle agents, PR description, and review dispositions when applicable.
Report those facts with the owner profile, review policy and reviewer profile
when used, validation, verification gaps, residual risks, and Herdr handles.
Leave the worktree, sessions, branch, and draft PR in place.

**Complete when:** the user has a tool-verified draft PR ready to inspect and no
merge occurred.
