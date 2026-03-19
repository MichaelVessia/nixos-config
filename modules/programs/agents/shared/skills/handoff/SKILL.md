---
name: handoff
description: |
  Summarize remaining work and context for the next agent session.
  Trigger phrases: "handoff", "hand off", "pass it off", "next agent"
allowed-tools: Bash, Read, Glob, Grep
model: claude-sonnet-4-6
---

# handoff - Context Handoff for Next Agent

Produce a self-contained briefing so the next agent can pick up where this
session left off with zero ramp-up. Output it directly as text (do not write a
file).

## Process

### 1. Gather Context

Review the full conversation and extract:

- **Goal**: what the user is trying to accomplish (the "why")
- **Completed**: what was already done this session (commits with SHAs, files
  changed, PRs opened)
- **Remaining**: concrete next steps that still need doing
- **Blockers / open questions**: anything unresolved that the next agent should
  ask about or the user should weigh in on
- **Key decisions**: choices made and their rationale, so the next agent doesn't
  re-litigate
- **Important constraints**: rules, patterns, or guardrails the next agent must
  follow
- **Relevant paths**: files, directories, branches, URLs the next agent will need
- **Verification**: commands or checks that currently pass and should keep passing

### 2. Gather Live State

Run quick commands to capture current state:

- `git log --oneline -10` (recent commits)
- `git branch --show-current`
- `git status --short`

Incorporate this into the output where relevant (branch name, dirty files, etc).

### 3. Output the Handoff

Print the handoff directly as a markdown code block (` ```text `) so the user
can copy-paste it into the next session. Use a structure like this, but adapt
freely based on what's relevant:

```
Continue work in `<working directory>`.

Read first:
- `<spec or plan file>`
- `<other important file>`

Context:
- Goal: <concise goal>
- <branch, repo layout, or other orientation info>

Already completed and committed on `<branch>`:
- `<sha>` `<commit message>`
- `<sha>` `<commit message>`

What's already done:
- <plain English summary of completed work, with file paths>

Current expected next step:
- <the immediate thing the next agent should do>
- <with specific file paths and details>

Important constraints:
- <rule or pattern>
- <rule or pattern>

Useful commands that currently pass:
- `<command>`
- `<command>`

Suggested immediate workflow:
1. <step>
2. <step>

If anything seems inconsistent, trust the spec and plan files over this prompt.
```

Omit sections that have no content. Add sections if the context calls for it
(e.g., "Blockers", "Open Questions", "Key Decisions").

## Notes

- Optimize for the next agent's cold start. Assume it has zero prior context.
- Be specific: absolute file paths, commit SHAs, branch names, exact commands.
- Keep it concise but complete. No filler.
- The output should be a prompt that the user pastes, not a report to read.
  Write it as instructions to the next agent.
