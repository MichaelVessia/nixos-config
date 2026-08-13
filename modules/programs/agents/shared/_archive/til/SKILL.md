---
name: til
description: |
  Quickly log a Today-I-Learned note to Obsidian. Use when user says "/til",
  "today i learned", or asks to capture a small learning from current work.
  Bias toward the user prompt first, then inspect session context (recent
  messages, commands, files, errors, decisions) to enrich relevant details.
  Write a concise Obsidian note with front matter tags for TIL organization.
---

# til - Quick Today-I-Learned Logger

Arguments: `$ARGUMENTS`

Create a concise TIL note in `~/obsidian/Notes/`.

## Workflow

1. Parse prompt first.
   - Treat `$ARGUMENTS` (or text after `/til`) as primary source.
   - Keep user language and topic terms.

2. Enrich from session context.
   - Inspect recent context for details directly related to prompt topic.
   - Prefer concrete evidence from this session (commands, paths, errors, fixes).
   - If context is sparse, proceed with prompt-only note.

3. Keep content short and factual.
   - Title: `TIL: <topic>`.
   - `Learned` section: 1 to 3 concise bullets.
   - `Context` section: 1 to 3 concise bullets.
   - No fluff, no long writeup.

4. Write note file.
   - Ensure directory exists: `~/obsidian/Notes`.
   - Filename: `YYYY-MM-DDTHH-MM-SS-til-<slug>.md`.
   - Path: `~/obsidian/Notes/<filename>`.

Use this format:

```markdown
---
date: <ISO8601 timestamp>
daily: [[YYYY-MM-DD]]
tags:
  - til
  - today-i-learned
topic: <topic-slug>
source: agent
---

# TIL: <Title>

## Learned
- <fact 1>
- <fact 2 optional>
- <fact 3 optional>

## Context
- <session detail 1>
- <session detail 2 optional>
```

5. Confirm success.
   - Return the full note path.
   - Return a one-line summary of what was captured.

## Rules

- Prompt-first, context-second.
- Do not invent facts absent from prompt or session context.
- Keep note usable for quick later recall.
