---
name: herdr-dispatch
description: Use when the user explicitly asks Codex Desktop or another shell outside Herdr to create, inspect, prompt, follow up with, or monitor Herdr agent tabs, or when the `codex-herdr` router skill hands off external control.
---

# Herdr Dispatch

This local adapter permits explicit user-requested Herdr control from outside `HERDR_ENV=1`. Keep the upstream `herdr` skill unchanged and do not load it for this external workflow; its environment gate intentionally refuses external control.

## Safety and defaults

- Act only on an explicit request to control Herdr. A user request routed through the `codex-herdr` skill counts as explicit.
- Verify connectivity with `herdr workspace list`.
- Never assume the focused pane belongs to the external controller.
- Create one tab per agent with `--no-focus`. Split panes only when requested.
- Honor explicit harness, model, and thinking level. Ask if the harness conflicts with the model family, or if neither model nor harness is specified.
- Never close or remove panes, tabs, workspaces, agents, or worktrees unless requested.
- Nontrivial work is non-blocking by default: submit prompts without `--wait` and return control to the user (see Prompting and waiting).
- Do not create a worktree unless the user requests isolation. When they do request one, use Herdr's built-in `herdr worktree` flow (see Worktrees), never manual git plumbing.

## Harness and model routing

Interpret model phrases case-insensitively; spaces, hyphens, underscores, and dots are equivalent separators for matching.

- `fable`, `opus`, `sonnet`, `haiku`, and `claude-*` are Anthropic models and use Claude Code: `--kind claude`.
- An unversioned family name, or one followed by `latest`, passes that family alias to `--model` (`fable`, `opus`, `sonnet`, or `haiku`).
- An explicit version pins `claude-<family>-<version>`, replacing version dots with hyphens. Examples: `opus 4.8` → `claude-opus-4-8`, `OPUS-5` → `claude-opus-5`, `Sonnet 5` → `claude-sonnet-5`, `Haiku 4.5` → `claude-haiku-4-5`.
- Pass an already canonical `claude-*` model unchanged.
- All recognized non-Anthropic models use Pi: `--kind pi`. Normalize `5.6 sol`, `5.6 luna`, and `5.6 terra` to `openai-codex/gpt-5.6-sol`, `openai-codex/gpt-5.6-luna`, and `openai-codex/gpt-5.6-terra`, respectively.
- If the family is unclear, ask. If a generated version ID is rejected, report it and ask; never reroute or silently downgrade.

Pass the requested reasoning level to the selected harness:

- Claude Code: `--effort low|medium|high|xhigh|max`.
- Pi: `--thinking off|minimal|low|medium|high|xhigh|max`.
- If no level is requested, omit the flag and keep the harness default.
- If the requested level is unsupported by the selected harness, ask instead of silently changing it.

Claude Code sessions run with `--dangerously-skip-permissions`. Pi has no equivalent bypass flag; pass none. Pi's `--approve` trusts project-local resources and is not a tool-permission bypass.

Examples:

```bash
# “spawn a Fable agent on high”
herdr agent start fable-high \
  --kind claude \
  --pane <pane-id> \
  -- --model fable --effort high --dangerously-skip-permissions

# “spawn a 5.6 Luna agent on medium”
herdr agent start luna-medium \
  --kind pi \
  --pane <pane-id> \
  -- --model openai-codex/gpt-5.6-luna --thinking medium
```

## Dispatch

1. List workspaces and identify the requested workspace from current JSON output. Never guess an ID.
2. Create a tab in that workspace. Capture `result.root_pane.pane_id`; IDs are session-local. If the user asked for a worktree, replace this step with the Worktrees flow below.
3. Start the agent in that existing shell pane with `herdr agent start`.
4. Submit the task with `herdr agent prompt <agent> "<task>"`, no `--wait`.
5. Immediately report that the agent is running: agent name, workspace (and worktree if any), and its inspection/focus command. Do not poll; Herdr's UI already shows state.

Example, matching “create a tab in the Obsidian workspace and send `Hello` to Claude”:

```bash
herdr workspace list
herdr tab create --workspace <obsidian-workspace-id> \
  --cwd /Users/michael.vessia/obsidian \
  --label hello-claude \
  --no-focus
herdr agent start hello-claude \
  --kind claude \
  --pane <result.root_pane.pane_id> \
  -- --dangerously-skip-permissions
herdr agent prompt hello-claude "Hello"
# report now: hello-claude is running in obsidian; inspect with
#   herdr agent read hello-claude --source recent-unwrapped --lines 80
```

Names must be short and unique. Use the pane ID returned during creation as the fallback handle if agent-name detection is unavailable.

## Prompting and waiting

For nontrivial work (investigation, implementation, review, tests, PR work), submit without `--wait`, tell the user it is running, and return control. Reserve `--wait` for short, explicitly synchronous interactions or when the user asks to wait for completion in the current turn.

For completion follow-up, use a watcher. It must first wait for `working` so it cannot match the agent's initial idle state and falsely announce completion:

```bash
herdr agent wait <agent> --until working --timeout 60000 && \
  herdr agent wait <agent> --until idle --until done --until blocked
```

Herdr cannot wake the controlling chat itself; run the watcher through the controlling harness's wake mechanism so completion re-enters the conversation:

- Claude Code: run the watcher as a background Bash task (`run_in_background`); the session is re-invoked when it exits. Then `herdr agent read` and report.
- Pi: run it via `pi-interactive-shell` in dispatch mode with `background: true` and `handsFree: { autoExitOnQuiet: false }` — the watcher is silent while waiting and quiet-detection would kill it early. Completion wakes the turn via `triggerTurn`.
- Harness without a wake mechanism: detach the watcher with `( ... && herdr notification show "<agent> finished" --body "herdr agent read <agent>" --sound done ) &` for a desktop alert, then read and report on the next controlling turn. Do not promise a chat wake-up the harness cannot deliver.

## Follow-up

```bash
herdr agent list
herdr agent read <name-or-pane-id> --source recent-unwrapped --lines 120
herdr agent prompt <name-or-pane-id> "<follow-up>"
herdr agent wait <name-or-pane-id> --timeout 600000   # only when the user asked to wait; matches idle|done|blocked
herdr agent focus <name-or-pane-id>
```

## Worktrees

Applies only when the user asks for a Herdr worktree, worktree isolation, or a trackable worktree. Herdr has a first-class worktree flow (`herdr worktree create|open|list|remove`, plus the workspace menu's `New worktree` / `Open worktree...`); use it, never assemble the pieces by hand.

A worktree-backed child workspace is not a tab. `worktree create` makes a new workspace linked to the parent repo workspace; Herdr nests it under the parent and tracks branch, path, and removal. A tab whose cwd happens to be a worktree has none of that.

### Anti-patterns

Never approximate the flow with:

- manual `git worktree add`
- standalone `herdr workspace create` pointed at a worktree path
- `herdr tab create --cwd <worktree-path>` in the parent

All three lose the parent-workspace association Herdr's UI and worktree tracking depend on.

### Create

```bash
herdr workspace list   # find the parent repo workspace_id
herdr worktree create \
  --workspace <parent-workspace-id> \
  --branch <branch> \
  --base <base-ref> \
  --path <worktree-path> \
  --label <label> \
  --no-focus \
  --json
```

- Always pass `--workspace` with the parent's ID so the worktree lands under that workspace.
- Pass branch, base, path, and label explicitly. `--focus` only if the user wants to switch to it.
- Respect the repo's worktree path policy. Example: flo360 requires worktrees under `<repo-root>/.worktrees/`.
- Result type is `worktree_created`: `workspace` (the new child workspace), `tab`, `root_pane`, `worktree`. Capture `result.workspace.workspace_id` and `result.root_pane.pane_id`, then start the agent in that pane with `herdr agent start` as usual.

### Open an existing worktree

If the git worktree already exists on disk:

```bash
herdr worktree open \
  --workspace <parent-workspace-id> \
  --path <existing-worktree-path> \
  --no-focus \
  --json
```

Result type is `worktree_opened` with the same fields plus `already_open`. If `already_open` is true, check `herdr agent list` before starting anything in the returned pane.

### Verify and report

```bash
herdr worktree list --workspace <parent-workspace-id> --json
```

Entries with `open_workspace_id` are open in Herdr. Confirm the new worktree is listed under the parent's repo, then report the child `workspace_id`, the agent name, and its inspection command.

### Migrating a wrong setup

If an agent was already started outside this flow (manual worktree tab, standalone workspace):

1. Stop it safely first (`herdr agent wait ... --until idle`, then interrupt if needed). Never leave two agents writing to the same checkout.
2. Inspect the checkout and preserve uncommitted changes.
3. Attach the existing worktree properly with `worktree open --workspace <parent> --path <path>`.
4. Resume with a single agent in the new pane. Close the orphaned tab or workspace only with user permission.

### Removal

Never remove an active worktree manually (`git worktree remove`, `rm -rf`). Use `herdr worktree remove --workspace <worktree-workspace-id>` only after explicit user permission and after verifying no needed changes remain (`git -C <path> status`). Remove targets the worktree-backed child workspace's own ID, not the parent's. `--force` only if the user confirms discarding.

## Failures

- Workspace not found: report available workspaces; do not silently create a different context.
- Duplicate agent name: choose a unique role-oriented name.
- Agent fails to start: read the pane and report the CLI error.
- Command syntax differs: consult that command's current `--help`; do not reuse stale flags.
