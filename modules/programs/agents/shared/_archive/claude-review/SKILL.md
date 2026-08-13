---
name: claude-review
description: Perform a senior-level peer review of staged changes, then implement warranted fixes
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Read, Grep, Glob, Edit
---

## Workflow

### Step 1: Review staged changes

Read the staged diff and git status:

- `git diff --cached`
- `git status`

Review as a senior engineer. Produce a structured review with:

1. **Critical Issues** - bugs, security vulnerabilities, or breaking changes
   that MUST be fixed.
2. **Improvements** - concrete suggestions for better code quality, performance,
   or maintainability.
3. **Nitpicks** - minor style or preference items (low priority).

Rules:

- Be specific. Reference exact file paths and lines.
- Provide code examples for suggested fixes.
- Do NOT comment on formatting or whitespace.
- Do NOT suggest adding comments or docblocks unless something is genuinely
  confusing.
- Respect the project's CLAUDE.md rules and established patterns.
- Keep the review concise and actionable.

### Step 2: Present the review

Display the full review to the user.

### Step 3: Implement fixes

After presenting the review, evaluate your own feedback against the project's
patterns:

- **Implement** suggestions that are clearly correct improvements (bugs,
  security issues, genuine code quality wins).
- **Skip** anything that is purely stylistic preference, overly cautious, or
  conflicts with the project's established conventions.
- **Explain** which suggestions you're implementing and which you're skipping
  (and why).

After making changes, re-stage the modified files.
