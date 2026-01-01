---
allowed-tools: Bash
description: Log work activity to today's journal
model: claude-haiku-4-5
---

Create or append to today's journal file in `~/notes` (Obsidian vault). Intended for daily logging of activities, summaries, or notes.

Arguments: $ARGUMENTS

If arguments provided, use them as the entry content. If no arguments or arguments reference conversation context (e.g., "summarize what we did", "the error above"), use the conversation context to generate the entry.

Follow these steps precisely:

1. Determine today's date in YYYY-MM-DD format.
2. Check if `~/notes/YYYY-MM-DD.md` exists; if not, create it with a header `# Journal YYYY-MM-DD`.
3. Append a new timestamped entry: `## HH:MM` followed by the entry content as plain text on the next line(s)
4. Confirm successful addition by echoing the full path and entry.

Notes:

- Use Markdown syntax for all content.
- Ensure `~/notes` is a symlink to your full Google Drive Obsidian path.
- Designed for daily journaling of sessions, fixes, or thoughts.