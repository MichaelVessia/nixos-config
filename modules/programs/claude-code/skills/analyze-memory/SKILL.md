---
name: analyze-memory
description: Analyze sessions to suggest routing table improvements for memory files
allowed-tools: Read(**), Bash(ls:*), Bash(find:*), Bash(wc:*), Bash(stat:*), Bash(date:*), Bash(jq:*), Bash(cat:*)
---

## Context

State file location: `~/.claude/memory-analysis.json`
Sessions directory: `~/.claude/projects/`
Memory routing file: `~/.claude/CLAUDE.md`
Memory detail files: `~/.claude/memory/`

## Your Task

Analyze Claude Code session history to suggest improvements to the memory routing table.

### Steps

1. **Read state file** (create schema if missing):
   ```json
   {
     "lastRunAt": null,
     "lastSessionTimestamp": null,
     "sessionsAnalyzed": 0,
     "categoryHits": {},
     "patterns": []
   }
   ```

2. **Find new sessions**: Look in `~/.claude/projects/*/` for `.jsonl` files newer than `lastSessionTimestamp`

3. **Parse and classify each session** by:
   - File extensions touched (.ts, .tsx, .nix, .md, etc.)
   - Keywords in messages (test, refactor, debug, deploy, etc.)
   - Tools used (Bash with git, npm, nix, etc.)

4. **Update cumulative stats**:
   - Increment `categoryHits` for each category matched
   - Track emerging patterns not in routing table
   - Update `sessionsAnalyzed` count

5. **Write updated state file**

6. **Output routing suggestions**:

```markdown
## Routing Analysis (X new sessions)

### Category Hits (Y total sessions)
| Category | Sessions | % |
|----------|----------|---|
| typescript | 72 | 49% |
| testing | 45 | 31% |
| nix | 12 | 8% |

### Routing Suggestions

**New categories to add:**
- "refactoring" (23 sessions matched pattern)

**Consider demoting:**
- nix-environment.md (only 8% usage, could be inline)

**Current routing validated:**
- typescript.md: High usage, keep in routing table
```

### Category Detection Heuristics

| Category | Signals |
|----------|---------|
| typescript | .ts/.tsx files, tsc/tsx commands, type error messages |
| testing | test files, jest/vitest/bun test commands, "test" in messages |
| nix | .nix files, nix/nixos commands, flake references |
| git | git commands, commit/push/pr keywords |
| refactoring | "refactor" keyword, large file edits, rename patterns |

### Output Requirements

- Be specific about what sessions triggered each suggestion
- Include percentages to justify promotions/demotions
- Only suggest changes backed by data
