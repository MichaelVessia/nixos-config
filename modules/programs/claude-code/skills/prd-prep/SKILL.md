---
name: prd-prep
description: Transform a specification document into Ralph prd.json format. Use after spec-interview or when you have a complete spec. Triggers on "create prd", "generate prd.json", "convert spec to prd", "prep for ralph".
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion
---

# PRD Prep - Specification to prd.json Converter

Convert a technical specification into structured prd.json for Ralph autonomous execution.

## Arguments

`$ARGUMENTS` should be the path to the spec file (e.g., `docs/specs/FEATURE.md`)

## Steps

### 1. Read and Analyze Spec

Read the spec at `$ARGUMENTS`. Extract:
- Success criteria
- Phases and their checkpoints
- Technical requirements
- Verification commands

### 2. Analyze Codebase

Gather project metadata:
- Read `package.json` for project name
- Identify tech stack (Angular, NestJS, etc.)
- Check existing `ralph/prd.json` for format reference
- Note `specs_dir` convention (usually `docs/specs/`)

### 3. Decompose into Stories

For each phase in the spec, create stories following these rules:

**Story Sizing:**
- Small: Single file change, < 100 lines
- Medium: 2-5 files, 100-500 lines, one module
- Large: 5+ files, 500+ lines (consider splitting)

**Story ID Convention:**
```
{Phase}.{Epic}.{Story}
Example: 1.1.0, 1.1.1, 1.2.0, 2.1.0
```

**Acceptance Criteria Rules:**
Each criterion must be:
1. Verifiable: Can be checked with a command or file inspection
2. Specific: References exact file paths, test names, or commands
3. Independent: Doesn't depend on later stories

Good examples:
- "libs/common/foo/ exists with project.json"
- "yarn nx test foo passes"
- "Minimum 4 tests in schedule.controller.integration.spec.ts"

Bad examples:
- "Code is clean"
- "Feature works"
- "Tests pass" (which tests?)

### 4. Story Review (Approval Gate)

Present breakdown for approval using AskUserQuestion:

```
Decomposed spec into {N} stories:

Phase 1: {Phase Name}
  1.1.0 - {title} ({complexity})
  1.1.1 - {title} ({complexity})

Phase 2: {Phase Name}
  1.2.0 - {title} ({complexity})
  ...

Options:
- "Yes, generate prd.json"
- "Need changes" (then ask what to adjust)
```

Allow user to:
- Merge stories that are too granular
- Split stories that are too large
- Reorder or rename stories
- Add missing stories

### 5. Generate prd.json

After approval, write `ralph/prd.json`:

```json
{
  "project": "{from package.json name}",
  "description": "{one line from spec overview}",
  "version": "1.0.0",
  "created_at": "{today YYYY-MM-DD}",
  "updated_at": "{today YYYY-MM-DD}",
  "specs_dir": "docs/specs/",
  "available_specs": ["{SPEC_FILE.md}", "..."],
  "technology": {
    "{tech_name}": {
      "version": "^X.Y.Z",
      "packages": ["{package1}", "{package2}"],
      "notes": "{what it's used for, important caveats}"
    }
  },
  "reference_repos": {
    "{lib_name}": "{path/to/source/}"
  },
  "testing_policy": {
    "mandatory": "EVERY story MUST include tests. A story is NOT complete without passing tests.",
    "ui_changes": "{how to test UI changes}",
    "api_changes": "{how to test API changes}",
    "verification": "{command to run before marking complete}",
    "no_exceptions": "Do NOT mark a story as complete if tests are missing or failing."
  },
  "ui_patterns": {
    "state_management": "{pattern for state}",
    "styling": "{styling approach}",
    "data_fetching": "{how to fetch data}",
    "forms": "{form patterns}"
  },
  "stories": [
    {
      "id": "1.1.0",
      "phase": "{Phase Name}",
      "epic": "{Epic Name}",
      "title": "{Short imperative title}",
      "description": "{What needs to be done, context}",
      "specs": ["{SPEC_FILE.md}"],
      "acceptance_criteria": [
        "{Specific verifiable criterion}",
        "TESTS: {specific test requirement}"
      ],
      "technical_details": {
        "files": ["{path/to/file1.ts}", "{path/to/file2.ts}"],
        "pattern": "{implementation approach}"
      },
      "status": "pending",
      "estimated_complexity": "small|medium|large"
    }
  ]
}
```

**Field Notes:**
- `technology`: Include version, packages array, and notes for each tech
- `reference_repos`: Optional, map library names to source paths if available
- `testing_policy`: Required, define test expectations for each layer
- `ui_patterns`: Optional for UI projects, omit for backend-only
- `technical_details` in stories: List specific files to create/modify, patterns to follow

### 6. Validation

Before finishing:
1. Count stories per phase (aim for 3-7 per phase)
2. Check all acceptance criteria are verifiable
3. Ensure first story is small and foundational
4. Verify story IDs are sequential

### 7. Output Summary

```
PRD generated: ralph/prd.json
- {N} phases
- {M} stories total
- First story: {id} - {title}

Commands:
- ./ralph/scripts/prd-status.sh  # View PRD status
- ./ralph/ralph.sh               # Start autonomous loop
```
