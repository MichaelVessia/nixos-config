---
description: Start an autonomous Ralph Wiggum coding loop
allowed-tools: Bash(~/.claude/ralph:*)
---

# Ralph Wiggum Loop

Start an unattended autonomous coding loop that runs until the task is complete.

<!--
================================================================================
GUIDE TO RALPHING
================================================================================

The Ralph Wiggum approach lets you run long-running AI agents (hours, days) that
ship code while you sleep. The core idea:

    Run a coding agent with a clean slate, again and again until done.

WHY IT WORKS
------------
Each iteration starts fresh, avoiding context rot. By scoping to ONE small task
per iteration, you use only a fraction of the context window and stay effective.

THE CRITICAL RULES
------------------
1. SCOPE SMALL
   The #1 failure mode is picking tasks that are too large. You run out of
   context window and fail. Pick the smallest possible concrete next step.
   Ambitious = bad. Incremental = good.

2. KEEP CI GREEN
   Every commit MUST pass all tests and types. If you don't do this, you
   hamstring future iterations with bad code. They'll waste time bisecting
   to find bugs. Super nasty. Run checks BEFORE committing.

3. COMMIT YOUR WORK
   Commits let future iterations navigate what was done via git history.
   Small, atomic commits with descriptive messages.

4. TRACK PROGRESS
   The progress.txt file is critical. It's how future iterations (with fresh
   context) understand what's been done. Always append, never overwrite.
   Future you depends on past you documenting well.

5. HEALTHY FEEDBACK LOOPS
   Building really healthy feedback loops is CRITICAL to Ralph's success.
   Tests, types, linters - run them all. They're your safety net.

WHEN TO EMIT COMPLETE
---------------------
Only emit <promise>COMPLETE</promise> when:
- All requirements from the task are implemented
- All tests pass
- All type checks pass
- There is genuinely nothing left to do

If in doubt, don't emit it. Another iteration is cheap.

================================================================================
-->

## Task

$ARGUMENTS

## Instructions

Start the ralph loop with this task:

```bash
~/.claude/ralph -p "$ARGUMENTS"
```

The loop will:
1. Spawn fresh claude sessions repeatedly
2. Each session works on one small piece of the task
3. Progress is tracked in `progress.txt`
4. Commits are made after each piece of work (tests must pass)
5. Loop exits when complete or max iterations (default 10) reached

You can close this session after starting. Monitor progress via:
- `progress.txt` - detailed progress log
- `git log` - commits made by the loop
