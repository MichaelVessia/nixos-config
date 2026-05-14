---
name: spec-interview
description: Interview user to flesh out a spec file
allowed-tools: Read, Write, Edit, AskUserQuestion
---

Interview the user to develop a comprehensive specification document.

**Arguments:** `$ARGUMENTS` should be the path to the spec file (e.g., `./SPEC.md`, `docs/feature-spec.md`)

Follow these steps:

1. Read the spec file at `$ARGUMENTS`

2. Analyze the current spec and identify gaps:
   - Ambiguous requirements
   - Missing edge cases
   - Undefined error handling
   - Unclear data flows
   - Unspecified constraints
   - Missing integration points

3. Conduct an in-depth interview using AskUserQuestion:
   - Ask non-obvious questions the user likely hasn't considered
   - Cover: technical implementation, UI/UX, concerns, tradeoffs, constraints
   - Dig into specifics—avoid generic questions like "what should happen on error?"
   - Instead ask targeted questions like "if the websocket disconnects mid-transaction, should we retry, queue, or fail?"
   - Challenge assumptions in the spec
   - Explore edge cases and failure modes
   - Ask about performance, scale, security implications
   - Probe for unstated requirements and implicit assumptions

4. Continue interviewing iteratively:
   - After each answer, identify follow-up questions
   - Go deeper on complex areas
   - Don't stop until the spec is complete and unambiguous
   - Batch related questions (2-4 per round) to maintain flow

5. Once interview is complete, update the spec file:
   - Preserve existing structure where sensible
   - Add new sections for discovered requirements
   - Be specific and concrete—avoid vague language
   - Include decisions made during interview with rationale

Question categories to cover:

**Technical:**
- Data models and schema
- API contracts and error responses
- State management and transitions
- Concurrency and race conditions
- Caching and invalidation
- Migration strategy

**UX:**
- Loading and empty states
- Error messages and recovery flows
- Accessibility requirements
- Mobile/responsive behavior
- Keyboard navigation

**Constraints:**
- Performance budgets
- Backward compatibility
- Browser/platform support
- Regulatory/compliance

**Operations:**
- Monitoring and alerting
- Rollback strategy
- Feature flags
- A/B testing needs

Notes:
- Be relentless—a vague spec leads to rework
- Ask "what happens when X fails?" for every component
- If user says "I don't know", help them decide by presenting tradeoffs
