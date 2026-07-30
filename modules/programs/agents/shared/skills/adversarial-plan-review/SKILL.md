---
name: adversarial-plan-review
description: Run two heterogeneous fresh-context Herdr reviewers against both code quality and a governing plan, then synthesize evidence-backed feedback. Use when the user asks for a dual or adversarial review, code-versus-plan verification, or independent Claude and Pi reviewers before deciding whether a PR needs changes.
---

# Adversarial plan review

Use **independent lenses**: two fresh-context reviewers inspect the same complete target without seeing each other's reasoning. Each audits both implementation quality and fidelity to the governing plan. The parent resolves their evidence; reviewer consensus is not proof by itself.

## Invariants

- Review only. Reviewers never edit, commit, push, open, close, approve, or merge a PR.
- Do not review a moving target. Wait for the implementation owner to report ready and become idle.
- Give both reviewers the same code, base, plan, repository rules, and acceptance criteria.
- Keep reviewer contexts independent until both reports are complete.
- Require file/symbol evidence and exact commands. Label unsupported claims `[UNVERIFIED]`.
- Distinguish regressions from pre-existing issues and required changes from optional improvements.
- Never merge. Route fixes only when the user separately asks for implementation.

## 1. Resolve the review contract

Identify from tools and conversation context:

- repository and base branch;
- PR, branch, worktree, diff, or fleet of worktrees to inspect;
- governing plan, issue, PR body, task brief, or acceptance criteria;
- implementation owner and readiness state;
- repository instructions and required validation commands.

Prefer the original plan artifact over a summary written after implementation. If no governing artifact exists, ask the user for one because plan adherence cannot be established. Do not silently reinterpret the diff as its own specification.

For multiple related branches, include each branch's contract plus cross-branch compatibility and ordering constraints.

**Complete when:** the target is stable and every plan claim can be mapped to an acceptance criterion or explicitly marked unverifiable.

## 2. Choose heterogeneous reviewers

Read and follow the `herdr-dispatch` skill. Honor explicit harness, model, and reasoning choices. Otherwise default to:

- Claude Code: Fable 5, high effort.
- Pi: GPT-5.6 Sol, high thinking.

The parent chooses and records the exact harness/model IDs. Reviewers direct tooling or scope questions to the parent, not the user.

**Complete when:** two distinct reviewer configurations are explicit and supported by the installed harnesses.

## 3. Create one split review tab

1. Verify the intended Herdr workspace from current JSON output.
2. Create one non-focused tab rooted at the repository or neutral parent worktree.
3. Split the root pane once to the right at an even ratio.
4. Start one reviewer in each pane with short unique names.
5. Prompt both from the same prepared brief using [`references/reviewer-brief.md`](references/reviewer-brief.md).
6. Confirm each prompt was submitted and its agent transitions from idle to working. Some interactive harnesses can leave text in the input buffer; if so, send `ENTER` to that pane and recheck status.
7. If a reviewer exits before prompt delivery, inspect the pane error, recreate the pane, and retry by pane ID. Never silently substitute another model.

Start both reviews before waiting so their analysis runs concurrently.

**Complete when:** both panes are live, independently prompted, and working against the same immutable contract.

## 4. Collect complete reports

Wait until both reviewers are idle/done. Read enough output to capture their full reports, not only the terminal tail. If either report lacks criterion statuses, evidence, commands, or a verdict, send a focused follow-up and wait again.

Do not send one report to the other reviewer. A follow-up may clarify that reviewer's own evidence only.

**Complete when:** both reports satisfy the output contract independently.

## 5. Adjudicate findings

Build a combined finding table:

| Severity | Finding | Reviewer | Evidence | Plan criterion | Parent disposition |
| --- | --- | --- | --- | --- | --- |

For every finding:

1. Deduplicate shared root causes.
2. Verify cited code and command output before accepting it.
3. Resolve reviewer disagreements from repository evidence, not model reputation.
4. Classify as required change, optional improvement, false positive, pre-existing issue, or `[UNVERIFIED]`.
5. Identify cross-branch conflicts and sequencing constraints separately.

A single well-proven finding can block readiness. Two unsupported opinions do not.

## 6. Report the decision

Return:

1. overall `CHANGES REQUIRED`, `READY`, or `BLOCKED`;
2. verified required changes ordered by severity;
3. plan-adherence matrix for every criterion;
4. code-quality findings and optional improvements;
5. reviewer disagreements and their resolution;
6. cross-branch compatibility concerns;
7. exact models, commands, and validation evidence;
8. remaining `[UNVERIFIED]` claims.

Include the Herdr tab and reviewer handles for inspection. Do not claim that changes were applied. If the user asks to fix accepted findings, route each finding to the existing branch owner rather than creating competing implementations.
