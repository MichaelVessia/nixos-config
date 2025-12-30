---
description: Sync Claude commands to OpenCode commands format
---

# Sync Claude Commands to OpenCode

Convert Claude Code commands from `~/.claude/commands/` to OpenCode format at `~/.config/opencode/command/`.

## Skills

**No sync needed.** OpenCode natively searches `~/.claude/skills/<name>/SKILL.md` for skills.

## Commands

### Steps

1. Create `~/.config/opencode/command/` if it doesn't exist
2. Remove all existing `.md` files in `~/.config/opencode/command/`
3. List all `.md` files in `~/.claude/commands/`
4. For each file, read the content and convert:

### Frontmatter conversion

| Claude field | OpenCode field | Notes |
|--------------|----------------|-------|
| `description` | `description` | Keep as-is |
| `model` | `model` | Keep as-is |
| `allowed-tools` | (remove) | OpenCode doesn't use this |

OpenCode-only fields (not in Claude): `agent`, `subtask`

### Body

Keep the markdown body as-is. These work the same:
- Placeholders: `$ARGUMENTS`, `$1`, `$2`
- Shell injection: `` !`command` ``
- File references: `@filename`

5. Write converted files to `~/.config/opencode/command/`
6. Report which files were synced

## Example conversion

**Claude (`~/.claude/commands/foo.md`):**
```yaml
---
allowed-tools: Bash(git:*)
description: Do foo
model: claude-haiku-4-5
---
Run foo with $ARGUMENTS
```

**OpenCode (`~/.config/opencode/command/foo.md`):**
```yaml
---
description: Do foo
model: claude-haiku-4-5
---
Run foo with $ARGUMENTS
```

Proceed with the sync now.
