---
name: grounded-impl
description: Research codebase patterns before implementing; no abstract suggestions
args: <feature or problem to implement>
allowed-tools: Task, Read, Glob, Grep, Edit, Write
---

## Your task

Implement **$ARGUMENTS** grounded in existing codebase patterns.

Before suggesting any approach, spawn three parallel Task agents:

1. **Pattern search**: Search the codebase for existing patterns related to this feature/problem. Look for similar functionality, naming conventions, file organization.

2. **Convention discovery**: Read TypeScript/config conventions from tsconfig.json, eslint configs, and 2-3 existing modules most similar to what we're building. Note imports, error handling, typing patterns.

3. **Skeleton draft**: Based on initial exploration, draft a concrete implementation skeleton using actual imports, types, and patterns found in the codebase.

After all three complete, synthesize into a specific recommendation:

- Copy-paste-ready code that matches codebase style
- Use actual imports from existing files (no placeholder imports)
- Follow discovered naming conventions exactly
- Include types derived from existing patterns

**Rules**:
- No abstract suggestions. Only concrete code grounded in what already exists.
- If the codebase has no relevant patterns, say so explicitly and ask for guidance.
- Show which existing files informed each part of your implementation.
