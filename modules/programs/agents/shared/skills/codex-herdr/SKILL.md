---
name: codex-herdr
description: "Control herdr from the Codex Desktop app only. Use only when running in Codex Desktop and the user asks to inspect, focus, prompt, spawn, or manage herdr workspaces, tabs, panes, or agents. Do not invoke in Pi, Codex CLI, or other harnesses, even if they use a Codex model or the user says 'use Herder'."
---

# codex-herdr

Router for controlling herdr from the **Codex Desktop app only**. The host
application determines eligibility, not the model provider or model name. Pi
running a Codex model is still Pi, not Codex Desktop. If the host is not known to
be Codex Desktop, do not use this router; use the applicable native herdr skill
instead.

"Herder" and "herder" in a request mean herdr; the CLI binary is always `herdr`.
Once the Desktop-only gate is satisfied, pick the workflow from the environment.

1. Spawning an agent and handing it a task is dispatch. Read and follow the sibling `herdr-dispatch` skill (`../herdr-dispatch/SKILL.md`) in either environment. The user's request that fired this skill is the explicit request it requires.
2. Inspecting or controlling existing panes, tabs, and agents needs the CLI reference. Check `echo "${HERDR_ENV:-unset}"`. If `HERDR_ENV=1`, read and follow the sibling `herdr` skill (`../herdr/SKILL.md`). Otherwise use only the Follow-up commands in `herdr-dispatch`.
3. Verify connectivity first with `herdr workspace list`; if it fails, herdr is not running. Report that and stop.

## Boundary

The `herdr` skill's `HERDR_ENV` gate is intentional: it stops an outside shell from acting as if it owned the focused pane. Never set or fake `HERDR_ENV` to reach the native path, and never treat the focused pane as yours from outside. Outside Herdr, everything goes through `herdr-dispatch`.
