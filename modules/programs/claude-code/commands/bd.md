---
allowed-tools: Bash(bd:*)
description: Manage beads (issues) based on conversation context
---

# Beads Issue Management

You are managing issues using the beads (`bd`) issue tracker.

## Context

First, get current state:
```bash
bd prime
```

Then based on what we've discussed in this conversation:

1. **Check current issues**: `bd list --status=open`
2. **Review in-progress work**: `bd list --status=in_progress`
3. **Show blocked issues**: `bd blocked`

## Actions

Based on conversation context, determine appropriate actions:
- Create new issues discovered during work
- Update status of issues being worked on
- Close completed issues
- Add dependencies between related issues

## Session End Protocol

Before finishing:
```bash
bd sync
```
