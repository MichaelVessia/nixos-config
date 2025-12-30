---
allowed-tools: Bash(bd:*)
description: Initialize beads issue tracking in a repository
---

# Initialize Beads (bd)

Set up beads issue tracking in this repository.

## Steps

1. **Initialize beads**:
   ```bash
   bd init
   ```
   This creates `.beads/` directory with project database.

2. **Install git hooks** (auto-sync on commit):
   ```bash
   bd hooks install
   ```

3. **Add to agent instructions** (CLAUDE.md or AGENTS.md):

   If CLAUDE.md exists, append to it. Otherwise create AGENTS.md.

   Add this snippet:
   ```markdown
   ## Issue Tracking

   This project uses **bd (beads)** for issue tracking.
   Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

   **Quick reference:**
   - `bd ready` - Find unblocked work
   - `bd create "Title" --type task --priority 2` - Create issue
   - `bd close <id>` - Complete work
   - `bd sync` - Sync with git (run at session end)

   For full workflow details: `bd prime`
   ```

4. **Verify setup**:
   ```bash
   bd doctor
   ```

5. **Summary**: Report what was created and next steps.
