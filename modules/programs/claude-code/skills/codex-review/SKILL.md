---
name: codex-review
description: Send staged changes to Codex for independent peer review, then evaluate and implement warranted feedback
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Task(codex)
---

## Workflow

### Step 1: Send to Codex for review

Use the codex subagent to review staged changes. Pass it the following prompt:

> Review the staged git diff as a senior engineer. Provide:
>
> 1. **Critical Issues** - bugs, security vulnerabilities, or breaking changes
>    that MUST be fixed.
> 2. **Improvements** - concrete suggestions for better code quality,
>    performance, or maintainability.
> 3. **Nitpicks** - minor style or preference items (low priority).
>
> Be specific. Reference exact file paths and lines from the diff. Provide code
> examples for suggested fixes. Do NOT comment on formatting or whitespace. Do
> NOT suggest adding comments or docblocks unless something is genuinely
> confusing. Keep your review concise and actionable.

### Step 2: Present the feedback

Display Codex's full review to the user in a clear, formatted way.

### Step 3: Evaluate and implement

Read the staged diff yourself (`git diff --cached`) so you have full context,
then evaluate each piece of Codex's feedback:

- **Implement** suggestions that are clearly correct improvements (bugs,
  security issues, genuine code quality wins).
- **Ignore** anything that is purely stylistic preference, overly cautious, or
  conflicts with the project's established patterns, conventions, or CLAUDE.md
  rules.
- **Explain** briefly which suggestions you're implementing and which you're
  skipping (and why). You have greater context about this codebase than Codex
  does.

After making changes, re-stage the modified files.
