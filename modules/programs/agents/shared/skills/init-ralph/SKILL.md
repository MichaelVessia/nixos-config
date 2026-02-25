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

- `ralph/` directory with auto-loop scripts
- `ralph/ralph-auto-claude.jsonc` config file
- `ralph/ralph-auto-codex.jsonc` config file
- `ralph/scripts/` with ci-check and stream filtering utilities
- `.ralph-auto/` output directory (gitignored) during runs

After running, tell the user to:

1. Edit `ralph/ralph-auto-claude.jsonc` and `ralph/ralph-auto-codex.jsonc`
2. Ensure specs exist in `docs/prds/`
3. Run `./ralph/ralph-auto-claude.sh "<focus prompt>"` or `./ralph/ralph-auto-codex.sh "<focus prompt>"`
4. Optionally use `--judge` / `--judge-first` for completion validation
