---
allowed-tools: Bash(bd:*)
description: Find best candidates for next task
---

# Find Next Task

Find the best candidates for the next task to work on.

## Steps

1. **Get ready issues** (unblocked, available to work):
   ```bash
   bd ready
   ```

2. **Check in-progress work** (finish what's started):
   ```bash
   bd list --status=in_progress
   ```

3. **Review high priority open issues**:
   ```bash
   bd list --status=open --sort=priority
   ```

## Selection Criteria

Recommend issues based on:
1. Already in-progress (finish first)
2. High priority (P0, P1)
3. Unblocked (no dependencies waiting)
4. Quick wins (low effort, high value)

## Output

Present top 3-5 candidates with:
- Issue ID
- Title
- Priority
- Why it's a good candidate

Ask which one to start, then:
```bash
bd update <id> --status=in_progress
```
