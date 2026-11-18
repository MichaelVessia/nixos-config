---
name: codex-herdr
description: Route explicit Herdr control requests from Codex Desktop. Not for Codex CLI.
---

# codex-herdr

Router for controlling herdr from the **Codex Desktop app only**. The host
application determines eligibility, not the model provider or model name. If the
host is not known to be Codex Desktop, do not use this router; use the applicable native herdr skill
instead.

"Herder" and "herder" in a request mean herdr; the CLI binary is always `herdr`.
Once the Desktop-only gate is satisfied, pick the workflow from the environment.

1. Check `echo "${HERDR_ENV:-unset}"`. If `HERDR_ENV=1`, read and follow the sibling `herdr` skill (`../herdr/SKILL.md`). The user's request that fired this skill is the explicit request it requires. Otherwise, report that this session runs outside Herdr and stop.
2. Verify connectivity first with `herdr workspace list`; if it fails, herdr is not running. Report that and stop.

## Boundary

The `herdr` skill's `HERDR_ENV` gate is intentional: it stops an outside shell from acting as if it owned the focused pane. Never set or fake `HERDR_ENV` to reach the native path, and never treat the focused pane as yours from outside.
