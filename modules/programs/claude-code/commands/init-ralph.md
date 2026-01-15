---
description: Set up Ralph autonomous agent structure in a repository
---

# Initialize Ralph

Run the ralph-init.sh script to scaffold the Ralph autonomous agent structure.

```bash
ralph-init.sh
```

This creates:

- `ralph/` directory with ralph.sh loop script
- `ralph/prd.json` template for stories
- `ralph/RALPH_PROMPT.md` prompt template
- `ralph/scripts/` with ci-check, prd-status, prd-update utilities
- `.ralph/` directory (gitignored) for logs

After running, tell the user to:

1. Edit `ralph/prd.json` with their stories
2. Edit `ralph/scripts/ci-check.sh` with their CI commands
3. Use `/ralph-prep` to help populate prd.json from a spec
