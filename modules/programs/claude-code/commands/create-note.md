---
allowed-tools: Bash
description: Create a new markdown note in Obsidian knowledge base
---

Create a new `.md` file in `~/notes` (Obsidian vault).\
Intended for quick archiving of chat context, ideas, or research summaries —
especially when used with `/dump-context`.

Follow these steps precisely:

1. Generate a filename based on the provided title or, if none given, the
   current timestamp.\
   Example: `2025-10-16T12-30-00-my-note.md`
2. Save the file under `~/notes/`.
3. Add a header containing:
   - `# <title>`
   - `date: <ISO8601 timestamp>`
   - optional: `tags:` and `source:`
4. Append the note content body following the header.
5. Confirm successful creation by echoing the full path.

Notes:

- Use Markdown syntax for all content.
- Prefer concise titles with no spaces — they become filenames.
- Ensure `~/notes` is a symlink to your full Google Drive Obsidian path.
- Designed to work alongside `/dump-context` for persistent knowledge capture.
