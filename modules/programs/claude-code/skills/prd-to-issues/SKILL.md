---
name: prd-to-issues
description: Break a PRD into independently-grabbable implementation issues using vertical slices (tracer bullets). Use when user wants to decompose a PRD into actionable issues/tasks. Writes local markdown issue files next to the PRD instead of creating GitHub issues.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# PRD to Issues

Break a PRD into independently-grabbable issues using vertical slices (tracer bullets).

## Process

### 1. Locate the PRD

Ask for the PRD path (or accept from `$ARGUMENTS`), typically under `docs/prds/`.

Read and internalize the full PRD content before decomposing.

### 2. Explore the codebase

Read key modules and integration layers referenced in the PRD. Identify:

- Distinct integration layers the feature touches (for example: schema/data, backend/API, UI, tests, config)
- Existing patterns for similar features
- Natural seams where work can be parallelized

### 3. Draft vertical slices

Break the PRD into tracer bullet issues. Each issue must be a thin vertical slice that cuts through all needed layers end-to-end, not a horizontal slice of one layer.

<vertical-slice-rules>
- Each slice delivers a narrow but complete path through all required layers
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick slices
- The first slice should be the simplest possible end-to-end tracer bullet
- Later slices add breadth: edge cases, additional user stories, polish
</vertical-slice-rules>

### 4. Quiz the user

Present proposed breakdown as a numbered list. For each slice, show:

- Title: short descriptive name
- Layers touched: which integration layers this slice cuts through
- Blocked by: which other slices (if any) must complete first
- User stories covered: which user stories from the PRD this addresses

Ask:

- Is granularity right (too coarse or too fine)?
- Are dependencies correct?
- Should any slices be merged or split?
- Is first tracer bullet ordered correctly?
- Are any slices missing?

Iterate until approved.

### 5. Create local issue markdown files

Create issue files alongside the PRD:

- If PRD is `docs/prds/<topic>.md`, write issues to `docs/prds/<topic>.issues/`
- File naming:
  - `01-<slice-slug>.md`
  - `02-<slice-slug>.md`
  - ...
- Use two-digit sequence in dependency order (blockers first)
- Create directory if missing

In each issue file, use this template:

<issue-template>
Status: pending
Blocked by: None

## Parent PRD

`<path-to-prd>`

## What to build

A concise description of this vertical slice. Describe end-to-end behavior, not layer-by-layer implementation. Reference specific sections of the parent PRD instead of duplicating content.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Blocked by

- `<issue-id>` (if any, for example `02-auth-bootstrap`)

Or:

None, can start immediately.

## User stories addressed

Reference by number from the parent PRD:

- User story 3
- User story 7
</issue-template>

Issue ID convention:

- `<sequence>-<slice-slug>`
- Example: `01-basic-auth-handshake`

Tracking compatibility requirements:

- Always include `Status: pending` at creation time
- Keep `Blocked by:` metadata in sync with the `## Blocked by` section
- Use issue IDs that exactly match filename stems

### 6. Output summary

After generating all issue files, print a summary table:

```text
| ID | File | Blocked by | Status |
|----|------|------------|--------|
| 01-basic-auth-handshake | docs/prds/auth-rework.issues/01-basic-auth-handshake.md | None | Ready |
| 02-session-validation | docs/prds/auth-rework.issues/02-session-validation.md | 01-basic-auth-handshake | Blocked |
```

Do not modify or delete the parent PRD.
