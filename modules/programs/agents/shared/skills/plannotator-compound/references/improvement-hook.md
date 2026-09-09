# Optional planning hook

Use this only when the user requests persistent planning instructions or accepts the offer to install them. References to Phase 3 mean the completed analysis.

## Phase 6: Improvement Hook

After presenting the summary, ask the user if they want to enable an **improvement
hook** — this takes the corrective prompt instructions from section 7 of the report
and writes them to a file that Plannotator's `EnterPlanMode` hook can inject into
every future planning session automatically.

> "Would you like to enable the improvement hook? This will save the corrective
> prompt instructions to a file that gets automatically injected into all future
> planning sessions — so Claude sees your feedback patterns before writing any plan."

**If yes:**

The hook file lives at:

```
${PLANNOTATOR_DATA_DIR:-~/.plannotator}/hooks/compound/enterplanmode-improve-hook.txt
```

Create the `hooks/compound/` directory inside the data directory if it doesn't exist.

The file contents should be the corrective prompt instructions from Phase 3 —
the same numbered list that appears in section 7 of the HTML report. Write them
as plain text, one instruction per line, prefixed with their number. No HTML, no
markdown fences, no preamble — just the instructions themselves. The hook system
will inject this file's contents as-is into the planning context.

**If the file already exists:**

Read the existing file and present the user with a choice:

> "An improvement hook already exists from a previous analysis. I can:
>
> 1. **Replace** — Overwrite with the new instructions (the old ones are gone)
> 2. **Merge** — Combine both, deduplicating overlapping instructions and
>    keeping the best version of each
> 3. **Keep existing** — Leave the current hook as-is, skip this step
>
> Which would you prefer?"

- **Replace:** Overwrite the file with the new instructions.
- **Merge:** Read the existing instructions, compare with the new ones, and
  produce a merged set. Remove duplicates (same intent even if worded differently).
  When two instructions cover the same pattern, keep the more specific or
  actionable version. Re-number the final list sequentially. Write the merged
  result to the file. Show the user what changed (added N new, removed N
  redundant, kept N existing).
- **Keep existing:** Do nothing, move on.

**If no:** Skip this phase entirely.
