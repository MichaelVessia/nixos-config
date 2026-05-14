# Skill Purgatory

Skills here are on probation. They didn't earn their keep in active rotation
but I'm not ready to delete them outright. Sitting in this folder means:

- They are **not** symlinked into `~/.claude/skills`, `~/.codex/skills`, or
  `~/.config/opencode/skills`. Agents will not see or invoke them.
- They are still in git history, so reviving one is a `git mv` away.
- If I don't miss a skill after a reasonable stretch (call it a quarter),
  it gets deleted for real.

To revive a skill:

```sh
git mv modules/programs/agents/shared/_archive/<name> \
       modules/programs/agents/shared/skills/<name>
```

Then rebuild. The symlinks will reappear automatically because
`shared.nix` enumerates `./shared/skills/`.

To delete for good: `git rm -r` the directory and commit.
