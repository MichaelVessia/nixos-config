---
description: Add timestamped entry to today's journal
---

Create or append to today's journal file in `~/notes/` (Obsidian vault).
Intended for daily logging of activities, summaries, or notes.

Arguments: $ARGUMENTS (the journal entry content)

Follow these steps precisely:

1. Determine today's date in YYYY-MM-DD format.
2. Check if `~/notes/YYYY-MM-DD.md` exists; if not, create it with a header
   `# Journal YYYY-MM-DD`.
3. Append a new timestamped entry: `## HH:MM` followed by the content of $ARGUMENTS as plain text on the next line(s)
4. Confirm successful addition by echoing the full path and entry.

Notes:

- Use Markdown syntax for all content.
- Ensure `~/notes` is a symlink to your full Google Drive Obsidian path.
- Designed for daily journaling of sessions, fixes, or thoughts.

