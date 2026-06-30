---
name: herdr-dispatch
description: Dispatch user-visible coding or research agents through Herdr with Codex-Desktop-like thread ergonomics. Use when the user asks to use Herdr to spawn, dispatch, fan out, inspect, follow up with, or monitor agent workspaces/threads.
---

# Herdr Dispatch

Use Herdr as the dispatch layer for visible agent work. This skill is for launching and coordinating agents from any shell, including Codex Desktop. Do not inherit the `HERDR_ENV=1` restriction from the lower-level `herdr` pane-control skill.

## Defaults

- Agent harness: Claude.
- Claude launch: `claude --dangerously-skip-permissions`.
- Do NOT add `--dangerously-bypass-hook-trust` by default: current Claude builds (>= v2.1.x) reject it, the launched pane exits instantly, and you waste a spawn discovering this. Only add it if the user explicitly asks, and if the pane dies, retry once without it and note the fallback.
- Codex launch, when explicitly requested: `codex --dangerously-bypass-approvals-and-sandbox --ask-for-approval never --sandbox danger-full-access`.
- Ignore requested effort levels for now. Use harness defaults.
- Visibility: always user-visible in Herdr.
- Layout: one new **tab** per agent by default. Panes are a deliberate choice; only split when the user asks, and tile them into a grid. See `Tabs vs Panes`.
- Focus: use `--no-focus` unless the user explicitly asks to focus the spawned work.
- Names: short, useful, role-oriented names, such as `review-pr-4370`, `impl-auth`, or `research-herdr`.
- Cleanup: never close, archive, or remove Herdr workspaces/worktrees unless explicitly asked.

## Mental Model

- Herdr workspace = repo or durable context.
- Herdr worktree workspace = Codex Desktop style thread for code work.
- Herdr agent = named worker running inside that context.
- Fanout is allowed. For code fanout, create one worktree/thread per independent task by default.

For code repositories, default to a Herdr worktree. For Obsidian vault or research-only work, do not create a git worktree; start the agent directly in the vault or resolved context.

## Tabs vs Panes

A **tab** is a full-width thread, like a Codex Desktop thread. A **pane** is a split inside a single tab, so multiple agents share one screen side by side.

- Default to one **tab** per agent. Each dispatched agent gets its own tab.
- A pane is created by passing `--split right|down` to `herdr agent start` (or `herdr pane split`). Without `--split`, an agent lands in its own tab.
- Panes are a deliberate choice, not the default. Use them when the user asks to split, compare side by side, watch agents in one view, or tile them (`split`, `side by side`, `same screen`, `as a pane`, `grid`, `tile them`). When unsure, default to tabs.
- Fanout defaults the same way: N independent tasks means N tabs. Only collapse them into panes when the user asks, and then tile them as a **grid** (see `Pane grids`).

To guarantee a fresh tab deterministically, create it first and target it by id:

```bash
herdr tab create --workspace <workspace-id> --label <agent-name> --no-focus
# parse result.tab.tab_id from the JSON, then:
herdr agent start <agent-name> --tab <tab-id> --no-focus -- claude ...
```

If you do not pre-create a tab, omit `--split` and `agent start` opens a new tab on its own.

### Pane grids

When the user wants panes, tile them into a near-square **grid** so every agent stays readable. Do not chain `--split down` (or `--split right`) off the same growing pane; that produces one column (or row) of ever-thinner, eventually-unreadable splits.

For N agents, fill row-major into a grid sized `cols = ceil(sqrt(N))`, `rows = ceil(N / cols)`:

1. Start every agent normally with `agent start` (own tab, capture each `pane_id` from the JSON). The first agent's tab becomes the grid tab.
2. Move the rest into the grid tab beside a specific neighbor, choosing direction by grid position. Track the `pane_id` parked at each cell so later moves target the right neighbor:

```bash
# first pane of a new column: place to the right of the previous column's top pane
herdr pane move <pane-id> --tab <grid-tab-id> --split right --target-pane <top-pane-of-prev-column> --no-focus
# next row within a column: place below the pane directly above it
herdr pane move <pane-id> --tab <grid-tab-id> --split down --target-pane <pane-above> --no-focus
```

3. If cells come out uneven, balance with `herdr pane resize --direction <left|right|up|down> --amount <float> --pane <id>`.

Reporting should say `grid in tab <label> (<cols>x<rows>)` so the user knows the layout.

## Repo Resolution

Resolve repo/context in this order:

1. Explicit path in the user request.
2. Known repo alias from the request, for example `web-monorepo`.
3. Current working directory when it is clearly the intended repo.
4. `/Users/michael.vessia/obsidian` as fallback for research or ambiguous non-code work.

If the resolved context is `/Users/michael.vessia/obsidian` or another vault/research folder, skip `herdr worktree create`.

## Preflight

Before dispatching:

1. Verify Herdr is reachable with `herdr agent list` or `herdr workspace list`.
2. Optionally check integrations with `herdr integration status`.
3. If Claude/Codex integration status is outdated, warn briefly but continue unless status tracking is required for the task.
4. Check existing agents with `herdr agent list` and avoid duplicate names or obviously duplicate active work.

## Dispatch Workflow

For code work:

1. Resolve the repo path.
2. Create or open a Herdr workspace for the repo if needed.
3. Create one Herdr worktree per independent task:

```bash
herdr worktree create --cwd /path/to/repo --branch codex/herdr-<slug> --label <agent-name> --no-focus --json
```

4. Parse the returned JSON for the worktree path and workspace id when available.
5. Prime the new worktree's environment BEFORE starting the agent (see "Worktree environment" below). Skipping this leaves the agent in a degraded shell with the wrong toolchain.
6. Start the named agent in that worktree:

```bash
herdr agent start <agent-name> --cwd /path/to/worktree --workspace <workspace-id> --no-focus -- claude --dangerously-skip-permissions "<prompt>"
```

For Codex:

```bash
herdr agent start <agent-name> --cwd /path/to/worktree --workspace <workspace-id> --no-focus -- codex --dangerously-bypass-approvals-and-sandbox --ask-for-approval never --sandbox danger-full-access "<prompt>"
```

If the worktree command does not return a usable workspace id, omit `--workspace` and rely on `--cwd`. Always capture the `pane_id` from the `agent start` JSON result (e.g. `w4:p3`) and keep it as the durable handle for monitoring (see "Follow-Up and Monitoring").

By default, do not pass `--split` here: each agent gets its own tab. When fanning out several agents into the **same** workspace (no separate worktree per task), create a tab per agent first (`herdr tab create --workspace <id> --label <agent-name> --no-focus`, parse `result.tab.tab_id`) and pass `--tab <tab-id>` to `agent start`, so they land as separate tabs rather than accidentally splitting one. If the user deliberately wants them in panes, tile them into a grid instead (see `Pane grids`).

## Worktree environment

Repos like `web-monorepo` use direnv (`.envrc` → devbox/nix) to put the correct toolchain (node, pnpm, env vars) on PATH. A freshly created worktree is broken in **two** ways, and both must be fixed or the agent runs with the wrong, unpinned global tools and any repo build/test/lint misbehaves:

1. **direnv is blocked.** Approval is keyed by **path + content hash**, so every new worktree path starts blocked: `direnv: error .../.envrc is blocked. Run 'direnv allow'`.
2. **Gitignored local env files are missing.** A git worktree only carries *tracked* files. Local files like `.env` are gitignored, so they exist in the main checkout but not the worktree. devbox parses `.env` on activation and aborts if it is absent (`Error: failed parsing .env file`), which silently drops you back to system node/pnpm.

After `herdr worktree create`, before `herdr agent start`, prime the worktree. Only do this when the source repo's `.envrc` is already trusted (never blindly trust an unvetted `.envrc`):

```bash
REPO=/path/to/repo
WT=/path/to/worktree

if [ -f "$REPO/.envrc" ] && (cd "$REPO" && direnv status | grep -q "Found RC allowed"); then
  # 1. seed gitignored local env files that devbox/direnv needs
  for f in .env .env.local; do
    [ -f "$REPO/$f" ] && [ ! -e "$WT/$f" ] && cp "$REPO/$f" "$WT/$f"
  done
  # 2. approve direnv for the new worktree path
  direnv allow "$WT"
  # 3. (optional) pre-warm so the agent's first shell doesn't sit through the devbox build
  direnv exec "$WT" true
fi
```

If the repo has no `.envrc`, or direnv is unavailable, skip this silently. For Obsidian/research contexts, skip entirely. Verify success by checking the toolchain resolves into the worktree, not system paths: `direnv exec "$WT" bash -c 'command -v node'` should point at `$WT/.devbox/...`, not `/opt/homebrew/...`.

For Obsidian or research-only work:

```bash
herdr agent start <agent-name> --cwd /Users/michael.vessia/obsidian --no-focus -- claude --dangerously-skip-permissions "<prompt>"
```

Do not create a worktree for vault work.

## Waiting

After launch, wait only long enough to confirm the agent exists and has started:

```bash
herdr agent wait <agent-name> --status working --timeout 30000
```

If it is already idle or status detection is stale, read recent output instead:

```bash
herdr agent read <agent-name> --source recent-unwrapped --lines 80
```

If `agent wait`/`agent read` by name returns `agent_not_found`, the harness's herdr state hook is outdated (`herdr integration status` shows it as `outdated`) and the name never registered. Fall back to the `pane_id` captured from `agent start` and read the pane directly:

```bash
herdr pane read <pane-id> --source recent-unwrapped --lines 80
# verify the pane is still alive (a pane that vanished means the harness exited at launch):
herdr pane list --workspace <workspace-id>
```

A pane that disappears seconds after `agent start` means the launched CLI exited immediately. The usual cause is an unsupported flag (e.g. `--dangerously-bypass-hook-trust`); relaunch without it.

Return after spawn confirmation. Do not wait for task completion unless the user asks.

## Follow-Up and Monitoring

Use named agents as durable handles:

```bash
herdr agent list
herdr agent read <agent-name> --source recent-unwrapped --lines 120
herdr agent send <agent-name> "<follow-up prompt>"
herdr agent wait <agent-name> --status idle --timeout 600000
herdr agent focus <agent-name>
```

If `agent send` does not submit the prompt in the current harness, read the agent/pane metadata and send Enter with the appropriate Herdr pane command.

## PR Review Fanout

For a request like `use herdr to review PRs 1, 2, 3`:

- Create one worktree/thread per PR, each in its own **tab** by default. If the user asks to see them together, tile the PR panes into a grid (see `Pane grids`).
- Name agents `review-pr-1`, `review-pr-2`, `review-pr-3`.
- In each prompt, tell the worker to inspect the PR, review only, and report findings. If the user asked for fixes too, allow fixes, commits, pushes, and PR updates.
- Prefer checking out the PR branch in that worktree. If checkout fails, have the worker fetch and inspect the PR via GitHub CLI.

## Prompt Shape

Prompts should be self-contained, like Codex Desktop thread prompts. Include:

- Repo/context path.
- Exact task.
- Relevant PR numbers, branch names, or files.
- Whether work is read-only or may edit/commit/push/open PRs.
- User-specific overrides, such as skipped local checks, if provided.
- Expected final report.

## Reporting

After dispatch, tell the user:

- Agent name.
- Harness used.
- Repo/context.
- Worktree path for code work, or `no worktree` for Obsidian/research.
- How to inspect or follow up: `herdr agent read <name>`, or `herdr pane read <pane-id>` if the state hook is outdated and the name does not resolve.

Keep the report short.

## Notifications

Use Herdr notifications only when useful:

```bash
herdr notification show "agent blocked" --body "<short reason>" --sound request
herdr notification show "agent done" --body "<short result>" --sound done
```

Do not use notifications for routine spawn success unless the user asks.
