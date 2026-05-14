---
name: done
description: |
  End-of-session summary saved to Obsidian with bidirectional daily note linking.
  Trigger phrases: "done", "wrap up", "session done", "end session"
allowed-tools: Bash, Write, Read, Edit
---

# done - End-of-Session Summary

Capture what was accomplished this session and save to Obsidian with bidirectional links to today's daily note.

## Process

### 1. Summarize the Session

Review the conversation and extract:

- What was accomplished (concise bullet points)
- Key decisions made
- Ticket links (Jira, e.g. `KEY-123`)
- PR links (GitHub, e.g. `repo#123` or full URLs)
- Branch names
- Files changed and what changed in each

Derive a short title (3-6 words) summarizing the session.

### 2. Generate Filename

Format: `YYYY-MM-DDTHH-MM-SS-done-<slug>.md`

- Slugify the title: lowercase, hyphens for spaces, no special chars
- Example: `2026-02-17T14-30-00-done-fix-auth-token-refresh.md`

### 3. Create Done Note

Write to `~/obsidian/Notes/<filename>`:

```markdown
---
date: <ISO8601 timestamp>
daily: [[YYYY-MM-DD]]
tags:
  - done
  - claude-session
source: claude-code
---

# <Short title>

## Summary

- What was accomplished (bullet points)

## Links

- PR: [repo#123](url)
- Ticket: [KEY-456](url)
- Branch: `branch-name`

## Files Changed

- `path/to/file.ts` - what changed
```

Omit the Links section if no links were found. Omit individual link types (PR, Ticket, Branch) if not applicable.

### 4. Ensure Daily Note Exists

Check if `~/obsidian/Notes/YYYY-MM-DD.md` exists. If not, create it:

```markdown
# Journal YYYY-MM-DD
```

### 5. Append to Daily Note

Check if a `## Done` section exists in the daily note.

- If it exists, append the new entry under it.
- If it does not exist, append `## Done` followed by the entry at the end of the file.

Entry format:

```markdown
- [[YYYY-MM-DDTHH-MM-SS-done-slug|brief title]]
```

### 6. Confirm

Echo both file paths and a brief summary of what was captured.

## Notes

- The `daily: [[YYYY-MM-DD]]` frontmatter creates the backlink from done note to daily note.
- The `[[...]]` wikilink appended to the daily note creates the forward link from daily note to done note.
- Keep summaries focused on outcomes, not process.
