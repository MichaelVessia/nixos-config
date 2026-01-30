---
name: init-bun-test
description: Set up bun test in a project (with Effect support if applicable)
---

# Initialize Bun Test

Set up bun test for this project.

## Steps

1. **Detect if Effect project**:
   - Check package.json for `effect` dependency

2. **Create `bunfig.toml`**:

   **Standard project:**
   ```toml
   [test]
   root = "./src"
   testMatch = ["**/*.test.ts"]
   ```

   **Effect project:**
   ```toml
   [test]
   root = "./src"
   testMatch = ["**/*.test.ts"]
   ```

3. **Install test dependencies**:

   **Standard project:**
   ```bash
   bun add -D @types/bun
   ```

   **Effect project:**
   ```bash
   bun add -D @types/bun @codeforbreakfast/bun-test-effect
   ```

4. **Add scripts to package.json**:
   ```json
   "test": "bun test",
   "test:watch": "bun test --watch"
   ```

5. **Create example test file** (if no tests exist):

   **Standard (`src/example.test.ts`):**
   ```typescript
   import { describe, expect, it } from 'bun:test'

   describe('example', () => {
     it('works', () => {
       expect(1 + 1).toBe(2)
     })
   })
   ```

   **Effect (`src/example.test.ts`):**
   ```typescript
   import { describe, expect, it } from '@codeforbreakfast/bun-test-effect'
   import { Effect } from 'effect'

   describe('example', () => {
     it('works', () => {
       expect(1 + 1).toBe(2)
     })

     it.effect('works with Effect', () =>
       Effect.gen(function* () {
         const result = yield* Effect.succeed(42)
         expect(result).toBe(42)
       })
     )
   })
   ```

6. **Run tests** to verify setup:
   ```bash
   bun test
   ```

Ask before creating example test file if tests already exist.
