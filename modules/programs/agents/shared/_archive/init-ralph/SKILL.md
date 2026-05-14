---
name: init-ralph
description: Set up Ralph autonomous agent structure in a repository
---

# Initialize Ralph

Run `ralph-init` to scaffold the Ralph autonomous agent structure.

```bash
ralph-init
```

This creates:

- `ralph/` directory with loop script and prompt files
- `ralph/prd.json` story queue
- `ralph/progress.txt` progress log
- `ralph/RALPH_PROMPT.md` prompt template
- `ralph/scripts/` with CI, status, update, and stream filtering utilities
- `.ralph/` output directory (gitignored) during runs

After running, tell the user to:

1. Edit `ralph/prd.json`
2. Edit `ralph/scripts/ci-check.sh`
3. Optionally customize `ralph/RALPH_PROMPT.md`
4. Run `./ralph/scripts/prd-status.sh`
5. Run `./ralph/ralph.sh`
