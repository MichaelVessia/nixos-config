# Local Herdr placement policy

Shared by the native `herdr` skill and the external `herdr-dispatch` adapter. This is placement guidance, not authorization to control Herdr: follow the calling skill's environment and user-request gates first.

## Choose the requested container

- **New split:** add a pane inside the existing requested tab. Do not create a tab or workspace instead.
- **New tab:** create a tab under the same requested workspace with `--label` set to a short, descriptive task name, such as `auth-fix`, `api-review`, or `test-logs`. Do not leave numbered defaults or create a new workspace.
- **New worktree:** use Herdr's first-class `worktree create` or `worktree open` with `--workspace <parent-repo-workspace-id>`. It must be a linked child workspace nested under the appropriate repo workspace, not a tab whose cwd happens to be a worktree. See the shared [worktree flow](./worktrees.md) for creation, verification, and removal.
- Keep focus unchanged with `--no-focus` unless the user requests switching to the new context. Preserve the intended checkout/cwd explicitly.

Inside Herdr, resolve caller context through `pane current --current` and live inventory, with inherited IDs as context—not the UI-focused pane. Outside Herdr, resolve the requested workspace/tab from live inventory and conversation context; do not use `--current` or assume the focused pane is yours. If the intended tab/workspace is ambiguous, ask before creating anything.

If no container was requested, retain the calling skill's default: native Herdr uses a sibling split; external dispatch uses a named tab. Do not infer permission for a worktree from a request for a split or tab.

## Keep splits readable

1. Inspect the target tab's panes and geometry using `pane list --workspace <id>` and `pane layout --pane <id>`. Use the installed CLI's current output and help, not guessed geometry fields.
2. Honor an explicit target pane and direction. Otherwise select a large pane in that tab whose split will keep the overall layout balanced; do not repeatedly split only the newest or focused pane.
3. Split a wide pane right, a tall/narrow pane down, accounting for terminal character-cell proportions. Prefer roughly equal halves (`--ratio 0.5`). Aim for a grid rather than a long strip: on a wide single-pane tab, split right; then split each of the two columns down before subdividing a quadrant again. Reinspect after every split—do not blindly alternate directions.
4. Make the best available split without asking for layout approval. If space is tight, choose the largest suitable pane in the requested tab and the direction that leaves the most usable area; keep the requested split topology rather than substituting a tab. If geometry is unavailable, use known tab topology and previous split directions to make a balanced best-effort choice. Do not move, resize, or close existing panes just to force a grid. Ask only when the intended destination is ambiguous, not because the layout is crowded.
5. Run `herdr pane split <chosen-pane-id> --direction <right-or-down> --ratio 0.5 --cwd <task-cwd> --no-focus`. Capture the new ID from `.result.pane.pane_id`; start the agent there, never in the occupied pane that was split.

New tabs use `herdr tab create --workspace <id> --cwd <task-cwd> --label <short-task-name> --no-focus`; capture `.result.root_pane.pane_id`. Agent names and tab labels are separate: use a short unique agent name even when the tab already has a descriptive label.
