---
description: Audit codebase for tech debt and improvements
---

# Cleanup Audit

Audit the codebase for technical debt, code smells, and improvement opportunities.

## Steps

1. **Identify tech stack** from package.json, tsconfig.json, etc.

2. **Search for debt markers**:

   ```bash
   # Comments
   rg -n "TODO|FIXME|HACK|XXX|BUG|WARN" -t ts -t js src/

   # Linter disables
   rg -n "eslint-disable|biome-ignore|prettier-ignore|oxlint-ignore" -t ts -t js src/
   ```

3. **Search for type safety violations** (high priority):

   ```bash
   # TypeScript directive escapes
   rg -n "@ts-ignore|@ts-expect-error|@ts-nocheck" -t ts src/

   # Type assertions (as Type) - should use type guards or proper typing
   rg -n " as [A-Z]| as any| as unknown" -t ts src/

   # Non-null assertions (!) - should use proper null checks
   rg -n "!\.|!\[|!;|!\)|!," -t ts src/

   # Explicit any types - should use proper types or unknown
   rg -n ": any|<any>|any\[\]" -t ts src/
   ```

4. **Check for common issues**:
   - `console.log` left in code (not in dev/debug files)
   - Empty catch blocks
   - Unused imports/variables (if no linter)
   - Hardcoded values that should be config
   - Dead code / unused exports
   - Missing error handling
   - Async functions without try/catch or .catch()

5. **Framework-specific checks**:
   - **React**: missing keys, inline functions in render, missing deps in useEffect
   - **Effect**: not using Effect patterns where appropriate
   - **Node**: sync fs operations, missing await

6. **Pattern violations**:
   - Review CLAUDE.md/AGENTS.md for stated patterns
   - Look for inconsistencies with established patterns in the codebase

## Output

Create a report organized by category:

1. **Critical** (should fix now)
2. **High** (fix soon)
3. **Medium** (tech debt to track)
4. **Low** (nice to have)

For each item include:
- File and line number
- What was found
- Suggested fix or action

Ask if you should:
- Create beads issues for items (`bd create`)
- Fix any items directly
- Just report findings
