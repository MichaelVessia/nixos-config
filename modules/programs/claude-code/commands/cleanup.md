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
   grep -rn "TODO\|FIXME\|HACK\|XXX\|BUG\|WARN" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" src/

   # TypeScript escapes
   grep -rn "@ts-ignore\|@ts-expect-error\|@ts-nocheck\|as any\|as unknown" --include="*.ts" --include="*.tsx" src/

   # Linter disables
   grep -rn "eslint-disable\|biome-ignore\|prettier-ignore\|oxlint-ignore" --include="*.ts" --include="*.tsx" --include="*.js" src/

   # Type assertions
   grep -rn "as [A-Z]\|!\\." --include="*.ts" --include="*.tsx" src/
   ```

3. **Check for common issues**:
   - `console.log` left in code (not in dev/debug files)
   - Empty catch blocks
   - Unused imports/variables (if no linter)
   - `any` types in TypeScript
   - Hardcoded values that should be config
   - Dead code / unused exports
   - Missing error handling
   - Async functions without try/catch or .catch()

4. **Framework-specific checks**:
   - **React**: missing keys, inline functions in render, missing deps in useEffect
   - **Effect**: not using Effect patterns where appropriate
   - **Node**: sync fs operations, missing await

5. **Pattern violations**:
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
