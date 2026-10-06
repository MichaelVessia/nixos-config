# vessia

A vendored fork of [pstack](https://github.com/cursor/plugins/tree/main/pstack)
and the cursor-team-kit skills it uses. Edit any file here directly; the
`pstack-sync` skill merges upstream releases without overwriting local changes.

## Layout

- `skills/`: every upstream pstack skill plus the `team-kit` skills named in
  `upstream.conf`. `modules/programs/agents/shared.nix` installs each
  directory as a skill.
- `agents/`: subagent prompts, installed at `~/.agents/vessia/agents/`.
- `LICENSE`: upstream MIT license. Keep it.
- `upstream.conf`: the upstream repository, the last synced revision, the
  vendored team-kit skills, the dropped upstream skills, and the tools you do
  not have.

## Rename

`pstack-sync` renames upstream paths and contents with
`modules/programs/agents/shared/skills/pstack-sync/scripts/transform.pl`
(`pstack` to `vessia`, `poteto` to `vessia`, and skill names that are not
valid IDs). It applies the same rules to the merge base and to the new
upstream revision, so the rename never counts as a local change. Put other
changes in the files themselves.

## Customize

- Edit a file: change it here. The next sync keeps your change and merges
  upstream edits around it.
- Remove an upstream skill: delete its directory and add `drop <name>` to
  `upstream.conf`. Without the `drop` line, the next sync restores it.
- Add a team-kit skill: add `team-kit <name>` to `upstream.conf` and sync.
- Show your local changes: `pstack-sync --local-diff`.
- Mark a tool you do not have: add `unavailable <name> <perl regex>` to
  `upstream.conf`. Syncs flag new upstream lines that match, and
  `pstack-sync --scan` lists every current match.
