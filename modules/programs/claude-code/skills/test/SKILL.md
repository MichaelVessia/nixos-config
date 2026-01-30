---
name: test
description: Run test suite and fix any failures
---

# Run Tests and Fix Failures

Run the project's test suite and fix any failing tests.

## Steps

1. **Detect test command**:
   - Check `package.json` for `scripts.test` (JS/TS projects)
   - Check for `Cargo.toml` → `cargo test`
   - Check for `go.mod` → `go test ./...`
   - Check for `pyproject.toml` or `pytest.ini` → `pytest`
   - Check for `mix.exs` → `mix test`

2. **Detect package manager** (for JS/TS):
   - `bun.lock` → `bun run test`
   - `pnpm-lock.yaml` → `pnpm run test`
   - `package-lock.json` → `npm run test`
   - `yarn.lock` → `yarn run test`

3. **Run the test suite**

4. **If tests fail**:
   - Analyze the failure output
   - Read the failing test file(s)
   - Understand what the test expects
   - Fix the code (not the test) unless the test itself is wrong
   - Re-run tests to verify fix
   - Repeat until all tests pass

5. **Report results**:
   - Number of tests run
   - What was fixed (if anything)
   - Final pass/fail status

## Rules

- Never disable or skip tests to make them pass
- Fix the underlying code, not the test (unless test is clearly wrong)
- If a test seems wrong, ask before modifying it
