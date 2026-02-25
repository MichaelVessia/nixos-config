---
name: second-opinion
description: Get a peer review from the other AI agent. Claude invokes Codex, Codex invokes Claude. Automatically detects which agent is active.
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(codex *), Bash(claude *), Read, Grep, Glob, Edit, Task(codex)
---

## Detection

Determine which agent you are by checking environment variables:

- If `$CLAUDECODE` is set: you are Claude. Delegate review to **Codex**.
- Otherwise: you are Codex (or another agent). Delegate review to **Claude**.

## Workflow

### Step 1: Gather context

Run `git diff --cached` to get staged changes. If nothing is staged, fall back
to `git diff` for unstaged changes. Also run `git status` for overview.

### Step 2: Send for review

**If you are Claude** (delegate to Codex):

Use the codex subagent (Task tool with subagent_type=codex). Pass it:

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

**If you are Codex** (delegate to Claude):

Run:
```bash
claude --print "Review this staged git diff as a senior engineer. Provide: 1) Critical Issues - bugs, security vulnerabilities, breaking changes. 2) Improvements - concrete suggestions for code quality, performance, maintainability. 3) Nitpicks - minor items (low priority). Be specific with file paths and lines. Provide code examples. Do NOT comment on formatting/whitespace or suggest adding comments unless genuinely confusing. $(git diff --cached)"
```

### Step 3: Present the feedback

Display the other agent's full review to the user in a clear, formatted way.

### Step 4: Evaluate and implement

Read the diff yourself so you have full context, then evaluate each piece of
feedback:

- **Implement** suggestions that are clearly correct improvements (bugs,
  security issues, genuine code quality wins).
- **Ignore** anything that is purely stylistic preference, overly cautious, or
  conflicts with the project's established patterns, conventions, or CLAUDE.md
  rules.
- **Explain** briefly which suggestions you're implementing and which you're
  skipping (and why). You have greater context about this codebase than the
  reviewing agent does.

After making changes, re-stage the modified files.
