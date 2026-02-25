---
name: bd-load
description: Parse context and create beads from it
allowed-tools: Bash(bd:*)
---

# Load Issues from Context

Parse the conversation context and create beads issues from discovered work.

## Process

1. **Review conversation** for:
   - TODOs mentioned
   - Bugs discovered
   - Features discussed
   - Technical debt identified
   - Follow-up tasks needed

2. **Check existing issues** to avoid duplicates:
   ```bash
   bd list --status=open
   ```

3. **Create issues** for each discovered item:
   ```bash
   bd create --title="<title>" --type=<task|bug|feature> --priority=<0-4>
   ```

4. **Add dependencies** if work items are related:
   ```bash
   bd dep add <issue> <depends-on>
   ```

## Priority Guide

- P0: Critical/blocking
- P1: High priority
- P2: Medium (default)
- P3: Low priority
- P4: Backlog

After creating all issues, sync:
```bash
bd sync
```

Report created issues with IDs.
