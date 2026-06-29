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
- Focus: use `--no-focus` unless the user explicitly asks to focus the spawned work.
- Names: short, useful, role-oriented names, such as `review-pr-4370`, `impl-auth`, or `research-herdr`.
- Cleanup: never close, archive, or remove Herdr workspaces/worktrees unless explicitly asked.

## Mental Model

- Herdr workspace = repo or durable context.
- Herdr worktree workspace = Codex Desktop style thread for code work.
- Herdr agent = named worker running inside that context.
- Fanout is allowed. For code fanout, create one worktree/thread per independent task by default.

For code repositories, default to a Herdr worktree. For Obsidian vault or research-only work, do not create a git worktree; start the agent directly in the vault or resolved context.

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

- Create one worktree/thread per PR.
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
