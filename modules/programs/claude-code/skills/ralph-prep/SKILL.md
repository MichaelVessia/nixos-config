---
name: ralph-prep
description: Full Ralph preparation workflow - create spec skeleton, interview to flesh out, generate prd.json. Triggers on "ralph prep", "prep ralph", "prepare for ralph", "set up ralph for".
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Skill
---

# Ralph Prep - Full Preparation Workflow

Orchestrate complete Ralph preparation: spec creation, interview, and prd.json generation.

## Arguments

The user provides a feature description. Extract a short kebab-case name from it for file naming.

Examples: auth-refactor, integration-tests, spotify-integration

User input: $ARGUMENTS

## Steps

### 1. Check Existing State

Use AskUserQuestion:
```
Do you have an existing spec, or should we create one?
Options:
- "Create new spec" (recommended)
- "Use existing spec" (provide path)
```

### 2. Create Spec Skeleton (if creating new)

Gather initial context with AskUserQuestion:

**Round 1 - What:**
```
What feature/initiative is this?
Options:
- [User describes in "Other"]
```

**Round 2 - Why & Scope:**
```
Questions (multi-select where appropriate):
1. What problem does this solve?
2. What's explicitly OUT of scope?
3. Any Jira ticket or reference doc?
```

### 3. Generate Spec Skeleton

Create `specs/{FEATURE_NAME}.md` with structure:

```markdown
# {Feature Name} Spec

## Overview

**Jira:** [TICKET-ID](link)

{Problem statement from interview}

## Success Criteria

- [ ] {Extracted from answers}

## Out of Scope

- {From answers}

## Phase 1: {TBD}

### {Section}

{Placeholder - to be fleshed out}

### Phase 1 Checkpoint

- [ ] TBD

## Verification Commands

```bash
# TBD
```
```

### 4. Call spec-interview

Invoke the spec-interview skill to flesh out the skeleton:

```
Skill: spec-interview
Args: specs/{FEATURE_NAME}.md
```

Wait for spec-interview to complete its interview process.

### 5. Verify Ralph Infrastructure

Check ralph setup exists:
- `ralph/ralph.sh` executable
- `ralph/RALPH_PROMPT.md` exists
- `ralph/scripts/` helpers exist

If missing, inform user:
```
Ralph infrastructure not found. See ralph/HOW_TO_RALPH.md for setup.
```

### 6. Call prd-prep

Convert the completed spec to prd.json:

```
Skill: prd-prep
Args: specs/{FEATURE_NAME}.md
```

### 7. Final Summary

```
Ralph preparation complete!

Spec: specs/{FEATURE_NAME}.md
PRD: ralph/prd.json ({N} stories)

First story: {id} - {title}

Commands:
- ./ralph/scripts/prd-status.sh  # View status
- ./ralph/ralph.sh               # Start loop
- ./ralph/ralph.sh 20            # Run 20 iterations
```

## Error Handling

If user cancels during spec creation:
- Save partial progress
- Inform user they can resume with `/spec-interview specs/{file}.md`

If prd.json already exists:
```
AskUserQuestion:
ralph/prd.json already exists ({N} stories). What to do?
Options:
- "Replace with new PRD"
- "Add stories to existing PRD"
- "Cancel"
```
