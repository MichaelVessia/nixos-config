---
name: bd-add
description: Create a new bead with provided arguments
allowed-tools: Bash(bd:*)
---

# Create New Bead

Create a new issue in beads.

## Usage

Arguments: $ARGUMENTS

If arguments provided, parse them for:
- Title (required)
- Type: task, bug, feature (default: task)
- Priority: 0-4 or P0-P4 (default: 2)

## Command

```bash
bd create --title="<title>" --type=<type> --priority=<priority>
```

## Examples

- `/bd-add Fix login button` → `bd create --title="Fix login button" --type=task --priority=2`
- `/bd-add bug: API returns 500 on empty input` → `bd create --title="API returns 500 on empty input" --type=bug --priority=2`
- `/bd-add P1 feature: Add dark mode` → `bd create --title="Add dark mode" --type=feature --priority=1`

After creating, show the issue ID.
