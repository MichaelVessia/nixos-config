---
name: herdr-dispatch
description: Dispatch self-contained work to Herdr agent tabs from a shell outside Herdr (HERDR_ENV unset). Use when the user explicitly asks to spawn, prompt, or follow up with a Herdr agent from outside Herdr.
---

# Herdr Dispatch

External adapter for controlling Herdr from outside `HERDR_ENV=1`. The sibling `herdr` skill is the native, inside-Herdr workflow; do not load it here. Command syntax comes from the installed CLI's `--help`, not from this file.

Dispatch is a **handoff**: launch one self-contained session, verify the prompt arrived, return the **receipt**, and stop. The destination session owns the task. The sending chat does not poll, wait, or steer unless the user asks again.

## Rules

- Act only on an explicit request to control Herdr. A request routed through `codex-herdr` counts.
- Never treat the focused pane as yours. Resolve every destination from live inventory. IDs are opaque handles: re-resolve after moves, never derive them from sidebar order.
- Follow the shared [placement policy](../herdr/placement.md) before creating any container. Unspecified placement means one short, task-named tab per agent with `--no-focus`.
- Honor explicit harness, model, and effort. Unspecified choices come from Assignment type below. Ask when an explicit harness conflicts with the model family or the level is unsupported by the harness.
- Never close or remove panes, tabs, workspaces, agents, or worktrees unless asked. If the requested workspace is not found, report the available ones; do not create a different context.
- Create a worktree only when the user asks for isolation, and only through [Herdr's worktree flow](../herdr/worktrees.md).

## Dispatch

1. Verify connectivity and inventory with `herdr workspace list`. Resolve the requested workspace and tab from the JSON.
2. Create the requested split, tab, or worktree per the placement policy. Capture `result.pane.pane_id` for splits and `result.root_pane.pane_id` for tabs and worktrees.
3. Pick the assignment type (see Assignment type) and start the agent in that pane: `herdr agent start <name> --kind <harness> --pane <pane-id> -- <flags>`. Names are short and unique; the pane ID is the fallback handle.
4. Compose the handoff prompt (see Handoff) and submit it with `herdr agent prompt <name> "<prompt>"`, without `--wait`. The task goes in the prompt, not in startup argv.
5. Read the transcript once: `herdr agent read <name> --source recent-unwrapped --lines 80`. A successful send is not proof of work. Classify the state as submitted, working, or blocked. If unclear, report that; never resend.
6. Return the receipt and stop.

The receipt: agent name, workspace and worktree path if any, assignment type, harness, model, effort, observed state, and the inspect and focus commands.

Example, "create a tab in the Obsidian workspace and send `Hello` to Claude":

```bash
herdr workspace list
herdr tab create --workspace <obsidian-workspace-id> \
  --cwd /Users/michael.vessia/obsidian --label hello-claude --no-focus
herdr agent start hello-claude --kind claude --pane <result.root_pane.pane_id> \
  -- --model claude-opus-4-8 --effort high --dangerously-skip-permissions
herdr agent prompt hello-claude "Hello"
herdr agent read hello-claude --source recent-unwrapped --lines 80
```

## Assignment type

Pick the type once, for the whole assignment. The session runs on one model for its whole life; there is no routing inside it.

| Type | When | Launch |
|---|---|---|
| Implement | Default. Any assignment that edits, including typos and renames. | `--kind pi -- --model openai-codex/gpt-5.6-sol --thinking high` |
| Implement, big or risky | The user says so, or the ticket is a large ambiguous feature or a multi-file refactor. | `--kind claude -- --model fable --effort high --dangerously-skip-permissions` |
| Review | Independent review or verification of an implementation in a fresh context. Beats Implement when both apply. | `--kind pi -- --model openai-codex/gpt-6-astra --thinking medium` |
| Research | Read-only gathering and factual summary, only when the user asks for a report. The prompt must forbid edits and generated files. | `--kind pi -- --model openai-codex/gpt-5.6-luna --thinking low` |

Explicit user choices override the table. A model pin picks its harness from the routing table below; without a level, keep the harness default. A harness-only request keeps the type's model if that harness serves it, else uses that provider's Implement profile. An effort-only request overrides the type's level. The type never grants extra authority or starts a reviewer unless review was requested. On a launch or submission failure, follow [fallback](./fallback.md).

Routing table for pinned models. Match case-insensitively; spaces, hyphens, underscores, and dots are equivalent separators.

| Request | `--kind` | Flags after `--` |
|---|---|---|
| `fable`, `opus`, `sonnet`, `haiku`, with or without `latest` | `claude` | `--model <family> --effort <level> --dangerously-skip-permissions` |
| Versioned family: `opus 4.8`, `Sonnet 5`, `Haiku 4.5` | `claude` | `--model claude-<family>-<version>`, dots become hyphens |
| Canonical `claude-*` | `claude` | `--model <as given>` |
| `5.6 sol`, `5.6 luna`, `5.6 terra` | `pi` | `--model openai-codex/gpt-5.6-<name> --thinking <level>` |
| `GPT6`, `GPT-6`, `Astra` | `pi` | `--model openai-codex/gpt-6-astra --thinking <level>` |

Levels: Claude Code `--effort low|medium|high|xhigh|max`; Pi `--thinking off|minimal|low|medium|high|xhigh|max`. Claude Code always runs with `--dangerously-skip-permissions`. Pi has no bypass flag; its `--approve` only trusts project-local resources. Never route Claude models through Pi's Claude bridge. Unclear family: ask.

## Handoff

The new session does not inherit this conversation and must survive the sending chat closing. Include the substance of decisions and findings, never "as discussed above". For nontrivial work, build the prompt from:

```text
Outcome: <user's request and acceptance criteria>
Context: <task cwd, relevant files, findings, decisions and constraints>
Starting state: <branch/base, existing changes and work already completed>
Scope: <allowed edits; files/shared resources to leave alone>
Validation: <checks and what completion means>
Authority: <what the user authorized; no commits, pushes, integration,
            destructive cleanup, or additional agents unless authorized>
Own this task in this session. Read the repository's instructions, carry out
and validate the work within scope, and report results or ask blocking
questions here. Do not depend on the sending chat, send messages to its pane,
or wait for it to collect a report or provide the next step.
```

- Every field is filled or explicitly `none`. Include issue/PR links with their known substance.
- Resolve paths against the destination checkout. A new worktree does not inherit uncommitted edits: inspect the starting state, arrange any transfer with permission, or report the gap before launching.
- One session per task, carrying its own implementation, validation, and review requirements. Launch more only when asked, each with an independent scope and no overlapping writers.

## Follow-up

Only on a new explicit request:

```bash
herdr agent list
herdr agent read <name-or-pane-id> --source recent-unwrapped --lines 120
herdr agent prompt <name-or-pane-id> "<follow-up>"
herdr agent wait <name-or-pane-id> --timeout 600000   # only when the user asked to wait; matches idle|done|blocked
herdr agent focus <name-or-pane-id>
```
