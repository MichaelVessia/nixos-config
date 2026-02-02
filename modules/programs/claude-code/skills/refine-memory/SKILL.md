---
name: refine-memory
description: Analyze sessions matching a category and suggest content improvements for that memory file
allowed-tools: Read(**), Bash(ls:*), Bash(find:*), Bash(jq:*), Bash(cat:*), Bash(grep:*)
args: <category>
---

## Context

Memory files location: `~/.claude/memory/`
Sessions directory: `~/.claude/projects/`
Argument: Category name (e.g., "typescript", "testing", "nix-environment")

## Your Task

Analyze sessions that match a specific category and suggest improvements to that memory file's content.

### Steps

1. **Read the target memory file**: `~/.claude/memory/{category}.md`

2. **Find matching sessions**: Search session JSONL files for signals matching this category:
   - typescript: .ts/.tsx files, tsc commands, type errors
   - testing: test files, test commands, assertion patterns
   - nix-environment: .nix files, nix commands, flake operations

3. **Analyze session patterns**:
   - What patterns emerged repeatedly?
   - What mistakes were made that rules should prevent?
   - What rules were followed vs ignored?
   - What additional guidance would have helped?

4. **Compare against existing rules** in the memory file

5. **Output content improvement suggestions**:

```markdown
## Content Analysis: {category}.md (analyzed X sessions)

### Current Rules Validated
- "Rule text" - followed in X/Y sessions
- "Rule text" - followed in X/Y sessions

### Suggested Additions
- **Add rule**: "Specific new rule text"
  - Pattern: Observed in X sessions
  - Would have prevented: [specific issue type]

- **Add rule**: "Another new rule"
  - Pattern: Observed behavior
  - Benefit: How this helps

### Suggested Modifications
- **Clarify**: "Existing rule text"
  - Issue: X sessions had confusion about this
  - Suggest: More specific wording or examples

### Rules Never Referenced
- "Rule text" - may be too specific or outdated
```

### Analysis Heuristics

For each session, look for:
- Error messages that indicate rule violations
- Patterns in code changes (what gets edited multiple times)
- Questions asked that indicate confusion
- Successful patterns worth codifying

### Output Requirements

- Be specific about which sessions informed each suggestion
- Quote actual rule text when referencing existing rules
- Provide concrete, actionable rule suggestions (not vague advice)
- Only suggest changes backed by observed patterns
