---
description: Run Ralph agent loop for N iterations
---

Run the ralph agent loop. Usage: `/ralph 10` (default: 10 iterations)

Execute this bash command:

```bash
ralph "${ARGUMENTS:-10}" "ralph" "$(cat <<'PROMPT'
# Ralph Agent Instructions

## Your Task

1. Read `ralph/prd.json`
2. Read `ralph/progress.txt` (check Codebase Patterns first)
3. Check you are on the correct branch
4. Pick highest priority story where \`passes: false\`
5. Implement that ONE story
6. Run typecheck and tests
7. Update AGENTS.md files with learnings
8. Commit: \`feat: [ID] - [Title]\`
9. Update prd.json: \`passes: true\`
10. Append learnings to progress.txt

## Progress Format

APPEND to ralph/progress.txt:

## [Date] - [Story ID]
- What was implemented
- Files changed
- **Learnings:**
  - Patterns discovered
  - Gotchas encountered
---

## Codebase Patterns

Add reusable patterns to the TOP of ralph/progress.txt:

## Codebase Patterns
- Migrations: Use IF NOT EXISTS
- React: useRef<Timeout | null>(null)

## Stop Condition

If ALL stories pass, reply:
<promise>COMPLETE</promise>

Otherwise end normally.
PROMPT
)"
```
