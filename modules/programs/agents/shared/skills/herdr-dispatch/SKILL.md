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
- Do not create a worktree unless the user requests isolation.

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
2. Create a tab in that workspace. Capture `result.root_pane.pane_id`; IDs are session-local.
3. Start the agent in that existing shell pane with `herdr agent start`.
4. Submit the task with `herdr agent prompt`.
5. Read the result and report the agent name plus its inspection command.

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
herdr agent prompt hello-claude "Hello" \
  --wait \
  --until idle \
  --until done \
  --timeout 60000
herdr agent read hello-claude --source recent-unwrapped --lines 80
```

Names must be short and unique. Use the pane ID returned during creation as the fallback handle if agent-name detection is unavailable.

## Follow-up

```bash
herdr agent list
herdr agent read <name-or-pane-id> --source recent-unwrapped --lines 120
herdr agent prompt <name-or-pane-id> "<follow-up>" --wait --timeout 600000
herdr agent wait <name-or-pane-id> --until idle --until done --timeout 600000
herdr agent focus <name-or-pane-id>
```

## Failures

- Workspace not found: report available workspaces; do not silently create a different context.
- Duplicate agent name: choose a unique role-oriented name.
- Agent fails to start: read the pane and report the CLI error.
- Command syntax differs: consult that command's current `--help`; do not reuse stale flags.
