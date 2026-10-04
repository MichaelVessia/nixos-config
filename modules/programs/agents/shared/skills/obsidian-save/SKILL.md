---
name: obsidian-save
description: Save requested notes or conversation context to the correct Obsidian vault. Ask before saving when the destination is ambiguous.
---

# Save to Obsidian

## Select the vault before writing

Choose by the note's content, not the current computer, repository, or working
folder. A personal project is not automatically FloSports work. Respect a clear
vault choice from the user, subject to the content and sharing checks below.

| Vault | Content | Devices |
| --- | --- | --- |
| `~/vaults/brain` | Reviewed general knowledge, public references, reusable instructions without work or private details | Work and personal devices |
| `~/vaults/flosports` | FloSports projects, meetings, internal systems, and work context | flomac and foundry |
| `~/vaults/private` | Personal records, journals, personal projects, and home infrastructure details | Personal devices only |

- If the destination is ambiguous, ask which vault to use and wait for the answer
  before creating or updating any note. Do not save to a default vault first.
- If a note mixes work, personal, and general information, ask whether to split it
  or keep it in a specified restricted vault. Do not copy the full note to brain.
- If the user selects brain but the proposed note contains work or private details,
  identify the conflict and ask what to remove or which restricted vault to use.
- General instructions can belong in brain after checking their content. Device
  lists, internal addresses, credentials, and personal context do not become
  general knowledge merely because they appear in a technical note.
- Check that the selected vault exists and read its `AGENTS.md` before writing.
  If it is unavailable, report that fact. Do not create a replacement vault, write
  to a different vault, or copy private notes onto a work device as a fallback.

## Save the note

1. Follow the requested focus, exclusions, title, and structure. Check for an
   existing note on the same topic and update it when appropriate. If its current
   vault conflicts with its content, resolve the destination before editing.
2. For a new note, use `<selected-vault>/Notes/YYYY-MM-DDTHH-MM-SS-<slug>.md`, unless
   the user or vault instructions specify another location. Use a lowercase slug
   with hyphens.
3. Keep the content limited to the requested information. Include relevant decisions,
   actions, and code examples without copying unrelated conversation details.
4. Include the date, a quoted `daily: "[[YYYY-MM-DD]]"` backlink, and the actual
   agent name in `source`. Do not label another agent's work as Claude Code.
5. Read the saved note to check its content and destination. Report the chosen vault
   and full path. Put the path in a code block so the app does not hide its folders.
   Confirm remote delivery only when sync status provides evidence.
