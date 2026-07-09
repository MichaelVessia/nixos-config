---
name: fanout-prs
description: Fan out a batch of work items into one PR each via isolated worktree agents, review every PR before it opens, then babysit all PRs through green CI and review feedback. Use when the user wants to fan out PRs, dispatch parallel PR agents over a list of items, or run a batch of independent changes as separate PRs.
---

# Fan-out PRs

Turn a list of independent work items into one PR per item: dispatch a worktree
agent per item, gate each PR before it opens, then babysit all of them to green.

The value is the fixed pipeline. The user supplies only what varies (the **spec**);
everything else has a default. Run the phases in order.

## Phase 1 — Parse the spec

From the user's request, extract:

- **items** — an explicit list, or a discovery instruction ("find the top 10 …").
- **mode** — `given-list` when items are named; `discover-and-rank` when they must
  be found. Infer from the request.
- **evidence** — the bar each PR must clear to be trustworthy (tests exercise the
  target / before-after benchmark in the PR body / meets acceptance criteria /
  lint+typecheck+tests pass with zero behavior change). **Required.** If the spec
  does not state it, ask for it and nothing else, then continue.
- **model** — subagent harness. Default: Opus (Claude).
- **pr** — `draft` or `ready`. Default: `draft`.
- **sequence** — items that touch the same files run serially; the rest parallel.
  Default: parallel.

## Phase 2 — Research and brief

Per item, produce a one-paragraph **brief**: the relevant code, how to run
verification, hidden constraints or ambiguity. A brief is *context, not
implementation instructions* — give the agent what it needs to design the fix, not
the fix. Flag any item that is underspecified or riskier than it looks; gate the
flagged ones on the user and proceed on the rest.

In `discover-and-rank` mode, first discover and rank the items, state the
assumptions behind the ranking, and get the user's go-ahead on the shortlist
before briefing.

## Phase 3 — Dispatch

For each item (honoring **sequence**), dispatch one worktree agent via the
`herdr-dispatch` skill — one worktree and PR per item. Pass the item's brief plus
the **per-agent contract** below verbatim. Let the agent design the
implementation unless you hold information it cannot discover.

### Per-agent contract (pass verbatim)

- Stay within this item's scope.
- Report adjacent bugs or spec gaps in the PR description; do not fix them.
- Follow repo conventions for branching, commits, and verification.
- Run the repo's full verification and satisfy the evidence bar: **{evidence}**.
- Every claim in the PR body must be backed by output from a command actually run
  in the session; include the command and raw output. Never estimate a number you
  did not measure — say it is unmeasured instead.
- Open the PR ({pr}) and drive its CI green.

## Phase 4 — Pre-PR gate

Before each PR opens, have a **fresh-context** subagent review the diff against a
lens derived from the evidence bar (do the tests actually exercise the target? is
the benchmark methodology sound with no behavior change? does the diff solve the
stated item, not an adjacent one?). Route findings back to the owning agent before
the PR opens.

## Phase 5 — Babysit

Watch all PRs together. Feedback and CI results arrive in waves. For each PR,
delegate monitoring and fixes to the `git-monitor-pr` and `git-fix-pr` skills;
route each failure or review comment back to that PR's owning agent. Loop until
every PR is green with all feedback resolved.

Report PR URLs and rolling status as you go.

## Autonomy contract (obey through Phases 3–5)

- Reversible action → proceed without asking.
- End your turn only when blocked on input only the user can provide.
- Never merge and never open a draft for review; the user gates all merges.
- Never force-push; never expand scope beyond the agreed item list.
- Back every status claim with a tool result from this session. Label anything
  unverified as unverified.
