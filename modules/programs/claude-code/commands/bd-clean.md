---
allowed-tools: Bash(bd:*)
description: Review and consolidate beads issues
---

# Clean Up Beads Issues

Review and consolidate the beads issue database.

## Steps

1. **Get overview**:
   ```bash
   bd status
   ```

2. **Find duplicates**:
   ```bash
   bd duplicates
   ```

3. **Find stale issues** (not updated recently):
   ```bash
   bd stale
   ```

4. **Review open issues**:
   ```bash
   bd list --status=open
   ```

5. **Check for issues that should be closed**:
   - Look for completed work
   - Look for issues superseded by others
   - Look for issues no longer relevant

## Actions

For each issue that needs attention:
- Close completed: `bd close <id>`
- Mark duplicate: `bd duplicate <id> <original-id>`
- Mark superseded: `bd supersede <old-id> <new-id>`

After cleanup:
```bash
bd sync
```

Summarize what was cleaned up.
