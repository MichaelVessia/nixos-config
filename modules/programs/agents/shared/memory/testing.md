# Testing Philosophy

## Core Principle

Test EVERYTHING. Tests must be rigorous. Our intent: ensure a new person contributing cannot break our stuff and nothing slips by. We love rigour.

## What to Test

- Every function that has logic worth verifying
- Edge cases and error paths, not just happy paths
- Integration points between modules
- Any bug fix should come with a regression test

## Test Execution

- Run only tests you added or modified (avoid wasting time on full suite)
- CI runs everything; check `.github/workflows` for what runs there
- Local should behave same as CI

## Test Quality

- Tests should fail for the right reasons
- One assertion per test concept (multiple asserts OK if related)
- Use descriptive test names that explain what's being verified
- Avoid testing implementation details; test behavior

## Never Disable Tests

If a test is failing:
1. Fix the code
2. Fix the test if it's wrong
3. Never `skip()` or comment out

## Mocking

- Mock external services and I/O, not internal modules
- Keep mocks minimal; prefer real implementations when fast enough
- Update mocks when interfaces change
