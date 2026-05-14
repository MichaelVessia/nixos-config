---
name: second-opinion
description: Get a peer review from the other AI agent. Claude invokes Codex, Codex invokes Claude. Automatically detects which agent is active.
allowed-tools: Skill
---

## Detection

Determine which agent you are by checking environment variables:

- If `$CLAUDECODE` is set: you are Claude. Delegate review to **Codex**.
- Otherwise: you are Codex (or another agent). Delegate review to **Claude**.

## Workflow

### If you are Claude

Invoke `codex-review` to send staged changes to Codex for review, then evaluate
and implement warranted feedback.

### If you are Codex

Invoke `claude-review` to perform a senior-level peer review of staged changes,
then implement warranted fixes.

The invoked skill handles the full flow: gathering the diff, performing the
review, presenting feedback, and implementing warranted fixes.
