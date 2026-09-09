---
name: obsidian-save
description: Save conversation decisions, solutions, or notes to the personal Obsidian vault when requested.
allowed-tools: Bash, Write
---

# obsidian-save - Save Session to Obsidian

Capture current session context as a note in the Obsidian vault.

## When to Use

Use when user wants to save conversation insights, decisions, or context to their Obsidian knowledge base.

## Process

1. **Parse user prompt**: The text accompanying the skill invocation guides the note:
   - **Focus areas**: "just the debugging steps", "only architecture decisions"
   - **Exclusions**: "skip the failed attempts", "don't include the tangents"
   - **Structure**: "as a how-to guide", "as bullet points", "as a decision log"
   - **Title**: Extract explicit title if given, otherwise derive from topic

2. **Generate filename**: `YYYY-MM-DDTHH-MM-SS-<slug>.md`
   - Use provided title as slug, or derive from session topic
   - Slugify: lowercase, hyphens for spaces, no special chars

3. **Summarize session** based on user's direction:
   - Default (no direction): decisions, solutions, key insights, action items
   - With direction: prioritize what user asked for, shape content accordingly
   - Use concise bullet points unless user requests different structure

4. **Create note** at `~/obsidian/Notes/<filename>`:

```markdown
---
date: <ISO8601 timestamp>
daily: [[YYYY-MM-DD]]
tags:
  - claude-session
source: claude-code
---

# <Title>

## Summary

<Bulleted summary of session>

## Details

<Any additional context, code snippets, or specifics worth preserving>
```

5. **Confirm**: Echo the full path and brief summary of what was captured.

## Notes

- Always include `daily: [[YYYY-MM-DD]]` for today's date to create backlink
- Keep summaries focused on actionable/memorable content
- Include code snippets only if they're the key takeaway
