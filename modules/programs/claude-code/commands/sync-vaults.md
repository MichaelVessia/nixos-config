---
allowed-tools: Bash(git pull:*), Bash(git -C:*), Bash(ls:*), Bash(ln:*)
description: Sync work notes from flo-notes into main Obsidian vault
model: claude-haiku-4-5
---

## Context

- Work vault location: ~/flo-vault (git repo)
- Main vault location: ~/obsidian
- Symlink: ~/obsidian/flo-vault -> ~/flo-vault

## Your task

Sync the work vault into the main Obsidian vault:

1. Ensure the symlink exists: `ln -sfn ~/flo-vault ~/obsidian/flo-vault`
2. Pull latest changes: `git -C ~/flo-vault pull`
3. Report what was updated (or if already up to date)

Do all of this in a single message with parallel tool calls where possible.
