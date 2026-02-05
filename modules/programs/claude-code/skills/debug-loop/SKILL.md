---
name: debug-loop
description: Autonomous debugging loop with up to 5 fix attempts
args: <error description or stack trace>
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Task
---

## Issue to debug

$ARGUMENTS

## Your task

Debug this issue autonomously. Follow this loop:

### For each iteration (max 5 attempts):

1. **Reproduce**: Run relevant tests or reproduction steps to confirm the failure
2. **Analyze**: Read stack traces, error messages, relevant code paths
3. **Hypothesize**: Form a specific theory about the root cause
4. **Fix**: Implement the fix
5. **Verify**: Re-run tests/reproduction

### Logging

After each iteration, output a summary:

```
## Attempt N

**Tried**: [specific change made]
**Result**: [pass/fail + details]
**Next**: [what you'll try if this failed, or "RESOLVED" if fixed]
```

### Exit conditions

- **Success**: Tests pass. Summarize the root cause and fix.
- **5 attempts exhausted**: Summarize all approaches tried and ask for guidance.
- **Truly ambiguous**: If you need clarification on expected behavior or the issue is unclear, ask. Otherwise keep iterating.

### Rules

- Start by finding and running the relevant test file(s)
- If no tests exist, create a minimal reproduction first
- Each attempt should try a meaningfully different approach
- Check environment variables and secrets early for auth errors (401, 403)
- Read error messages carefully; the answer is often in the stack trace
