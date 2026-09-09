# Herdr worktree flow

Shared by the native `herdr` skill and the external `herdr-dispatch` adapter. Applies only when the user asks for a Herdr worktree, worktree isolation, or a trackable worktree. Herdr has a first-class worktree flow (`herdr worktree create|open|list|remove`, plus the workspace menu's `New worktree` / `Open worktree...`); use it, never assemble the pieces by hand.

A worktree-backed child workspace is not a tab. `worktree create` makes a new workspace linked to the parent repo workspace; Herdr nests it under the parent and tracks branch, path, and removal. A tab whose cwd happens to be a worktree has none of that.

## Anti-patterns

Never approximate the flow with:

- manual `git worktree add`
- standalone `herdr workspace create` pointed at a worktree path
- `herdr tab create --cwd <worktree-path>` in the parent

All three lose the parent-workspace association Herdr's UI and worktree tracking depend on.

## Create

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

## Open an existing worktree

If the git worktree already exists on disk:

```bash
herdr worktree open \
  --workspace <parent-workspace-id> \
  --path <existing-worktree-path> \
  --no-focus \
  --json
```

Result type is `worktree_opened` with the same fields plus `already_open`. If `already_open` is true, check `herdr agent list` before starting anything in the returned pane.

## Verify and report

```bash
herdr worktree list --workspace <parent-workspace-id> --json
```

Entries with `open_workspace_id` are open in Herdr. Confirm the new worktree is listed under the parent's repo, then include the child `workspace_id` in the receipt.

## Migrating a wrong setup

If an agent was already started outside this flow (manual worktree tab, standalone workspace):

1. Stop it safely first (`herdr agent wait ... --until idle`, then interrupt if needed). Never leave two agents writing to the same checkout.
2. Inspect the checkout and preserve uncommitted changes.
3. Attach the existing worktree properly with `worktree open --workspace <parent> --path <path>`.
4. Resume with a single agent in the new pane. Close the orphaned tab or workspace only with user permission.

## Removal

Never remove an active worktree manually (`git worktree remove`, `rm -rf`). Use `herdr worktree remove --workspace <worktree-workspace-id>` only after explicit user permission and after verifying no needed changes remain (`git -C <path> status`). Remove targets the worktree-backed child workspace's own ID, not the parent's. `--force` only if the user confirms discarding.
