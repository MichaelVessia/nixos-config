---
name: fanout-prs
description: Fan out a user-provided task list into one reviewed PR per task through Herdr, then shepherd the PR fleet through CI and review without merging. Use when the user asks to fan out PRs, parallelize backlog items into separate PRs, or autonomously drive multiple agent-owned PRs to green.
---

# Fan-out PRs

Run a **PR fleet**: one task, owner, isolated worktree, branch, review gate, and PR per item. The parent agent owns decomposition, routing, evidence, and fleet state. Herdr agents own implementation and repair.

## Invariants

- Never merge. The user gates every merge.
- Keep each task in its own PR. Do not combine convenient leftovers.
- Use isolated worktrees. Never let two owners mutate the same worktree.
- Give owners researched context, not implementation recipes, unless a constraint is critical.
- The parent chooses each owner's harness, model, reasoning level, and tooling. Honor explicit user choices first; otherwise use judgment based on task complexity and repository conventions.
- Owners raise tooling, model, scope, or product questions to the parent, not the user.
- Proceed autonomously on reversible actions. Ask the user only for decisions or credentials only they can provide.
- Keep babysitting until every PR is green with actionable feedback resolved, or a user-only blocker remains.

## 1. Establish the fleet

1. Parse the user's list into independently reviewable tasks and preserve every requested item.
2. Identify dependencies and shared contracts before dispatch. Parallelize independent tasks; sequence only real dependencies.
3. Record a fleet row for each task:

   | Task | Owner | Harness/model | Branch | Worktree | PR | CI | Review | Blocker |
   | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

4. Read and follow the `herdr-dispatch` skill before controlling Herdr. Verify the target workspace and current CLI syntax rather than guessing IDs or flags.

**Complete when:** every task has one row, dependencies are explicit, and the initial dispatch wave is safe to run concurrently.

## 2. Research before dispatch

For each task, inspect enough of the repository to give the owner a useful brief:

- user-visible objective and acceptance criteria;
- likely files, symbols, and call paths;
- existing implementation and test patterns worth copying;
- repository instructions and relevant docs;
- focused and full validation commands;
- known risks, boundaries, dependencies, and non-goals.

Do not prescribe an implementation merely because one seems plausible. The owner should investigate and exercise judgment. Include a specific implementation constraint only when violating it would waste work or break a known invariant.

**Complete when:** every item has a source-grounded brief that lets a fresh agent begin without rediscovering basic repository context.

## 3. Create isolated owners

For each ready task:

1. Create a short unique branch from the intended base with Worktrunk, requesting JSON output and no directory change.
2. Capture the resulting worktree path.
3. Create a non-focused Herdr tab rooted at that worktree.
4. Start the explicitly selected harness and model in the returned pane.
5. Prompt the owner using [`references/owner-brief.md`](references/owner-brief.md).
6. Record the owner, branch, worktree, and Herdr handle in the fleet table.

Dispatch the ready wave without serially waiting on each owner. Respect machine capacity and task weight; “parallel” means useful concurrency, not maximum tab count.

**Complete when:** every ready item has a live owner in its own worktree with the complete brief and escalation protocol.

## 4. Gate before opening each PR

When an owner reports implementation and validation complete:

1. Launch a fresh-context, read-only reviewer against that worktree.
2. Prompt it using [`references/review-gate.md`](references/review-gate.md).
3. Route actionable findings to the owner.
4. Repeat with fresh context after material fixes until the gate is clean.
5. Only then instruct the owner to commit, push, and open the PR.
6. Capture the PR URL and verify its reported checks and review state.

The reviewer never edits, opens the PR, or replaces the owner. The owner retains branch responsibility.

**Complete when:** each opened PR passed a fresh-context gate and its URL is recorded from tool output.

## 5. Shepherd the fleet

Monitor CI and review feedback in waves rather than treating PR creation as completion:

1. Refresh every active PR's checks, review state, comments, and mergeability.
2. Classify new input as actionable, informational, stale, duplicate, or user-only.
3. Route actionable failures and feedback to that PR's owner with exact evidence.
4. Have the owner reproduce, fix, validate, push, and respond where appropriate.
5. Re-run the fresh-context gate when a fix materially changes behavior or scope.
6. Refresh the whole fleet after each wave; feedback often arrives asynchronously across PRs.
7. If an owner is unavailable, restart an owner in the same worktree with the fleet row, prior evidence, and unresolved work. Do not create a competing branch.

Do not silently dismiss review feedback. Use judgment, explain rejected suggestions with evidence, and escalate genuine product decisions to the user.

**Complete when:** every PR is green, actionable feedback is resolved, and no owner has unreported pending work.

## 6. Report with evidence

Send rolling status when PRs open, states materially change, or a blocker appears. Include:

- PR URLs;
- per-PR CI and review state;
- current owner/action;
- blockers and who can resolve them;
- tool-backed evidence from this session.

Label anything not directly verified as `[UNVERIFIED]`. Do not claim green from an owner's prose alone. Final output lists all PRs and states explicitly that none were merged.
