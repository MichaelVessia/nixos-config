---
name: write-a-prd
description: Create thorough PRDs through repo analysis and deep user interviews. Use for "create a PRD", "write requirements", "product spec", or "implementation plan". Writes PRDs to docs/prds and can optionally decompose them into local issue markdown files for Ralph.
allowed-tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Skill
---

# Write a PRD

Produce high-quality PRDs with explicit decisions, test strategy, and clear scope.

## Arguments

`$ARGUMENTS` may include:
- A feature/topic description
- A path to an existing spec (example: `docs/specs/feature-x.md`)
- Optional mode hint (`docs`, `issues`, or `both`)

If mode is not explicit:
- Default to `docs`
- Use `issues` when user asks for issue decomposition, tracer bullets, or Ralph-ready backlog generation

## Output Convention

### Docs PRD Mode (`docs`, default)

- Write to `docs/prds/`.
- File name must match PRD topic in kebab-case:
  - `docs/prds/<topic>.md`
  - Example: `docs/prds/homelab-service-health-dashboard.md`
- If file exists, append numeric suffix:
  - `docs/prds/<topic>-2.md`, then `-3`, etc.

### Issue Mode (`issues`)

- Generate local issue markdown files beside the PRD:
  - `docs/prds/<topic>.issues/*.md`
- Keep docs PRD as source of truth first, then derive issues from it.

## Workflow

### 1. Gather Problem Context

Ask for a long, detailed problem statement:
- What problem exists
- Who is impacted
- Why it matters now
- Any solution ideas already considered

If detail is thin, ask for concrete examples and failure cases.

### 2. Explore Repository Reality

Inspect the codebase before drafting:
- Existing modules and architecture
- Similar features and conventions
- Technical constraints and integration points
- Existing testing patterns (prior art)

Call out mismatches between assumptions and repo reality.

### 3. Interview Relentlessly

Drive iterative questioning until major ambiguity is eliminated.

Cover each branch of the design tree:
- Scope and explicit out-of-scope
- Actors and workflows
- Edge cases and failure recovery
- Data models, contracts, and state transitions
- Performance, security, and operational constraints
- UX states where relevant (loading, empty, error)

Do not stop at vague answers, force concrete decisions.

### 4. Propose Deep Modules and Test Scope

Sketch major modules to build/modify.

Prefer deep modules:
- Simple/stable interface
- Complex internals hidden behind that interface
- High testability with behavior-focused tests

Confirm with user:
- Module boundaries
- Which modules must be tested
- Critical behaviors each tested module must protect

### 5. Draft Docs PRD

Write markdown PRD with this template:

```markdown
## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

Example:
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.
```

### 6. Optional Issue Decomposition (`issues` or `both`)

Invoke `prd-to-issues` to decompose the approved PRD into tracer-bullet issue markdown files.

Requirements for generated issues:
- Vertical slices, end-to-end behavior, not horizontal layer chunks
- Explicit dependencies (`Blocked by`) in dependency order
- `Status: pending` metadata for workflow tracking
- Acceptance criteria checklists that are externally verifiable

### 7. Validate Outputs

For docs PRD:
- Check sections complete and coherent
- Check user stories cover main + edge workflows
- Check implementation/testing decisions are concrete and behavior-focused

For issue output:
- Check first issue is smallest end-to-end tracer bullet
- Check dependency graph is valid
- Check each issue has status, blockers, and acceptance criteria

### 8. Handoff

Report:
- Output file paths
- Key decisions made
- Remaining open questions/TODOs

If issue output exists, include:
- `./ralph/scripts/prd-status.sh`
- `./ralph/ralph.sh`
