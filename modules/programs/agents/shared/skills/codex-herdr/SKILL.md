---
name: codex-herdr
description: "Control herdr from Codex. Use when the user says \"use Herder\" or asks to inspect, focus, prompt, spawn, or manage herdr workspaces, tabs, panes, or agents from a Codex session, without deciding whether they are inside or outside herdr."
---

# codex-herdr

Router for controlling herdr from Codex. "Herder" and "herder" in a request mean herdr; the CLI binary is always `herdr`. Pick the workflow from the environment; the user never has to.

1. Check the environment: `echo "${HERDR_ENV:-unset}"`.
2. If `HERDR_ENV=1`, you are inside a herdr-managed pane. Read and follow the sibling `herdr` skill (`../herdr/SKILL.md`) — the native workflow.
3. Otherwise, you are an external controller. The user's request that fired this skill is the explicit request `herdr-dispatch` requires. Read and follow the sibling `herdr-dispatch` skill (`../herdr-dispatch/SKILL.md`). Verify connectivity first with `herdr workspace list`; if it fails, herdr is not running — report that and stop.

## Boundary

The `herdr` skill's `HERDR_ENV` gate is intentional: it stops an outside shell from acting as if it owned the focused pane. Never set or fake `HERDR_ENV` to reach the native path, and never treat the focused pane as yours from outside. External control always goes through `herdr-dispatch`.
