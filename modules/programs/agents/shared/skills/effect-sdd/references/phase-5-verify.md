# Phase 5: Verify

## Gate (must pass to ship)

- [ ] All previous phase tests still pass
- [ ] CLI smoke tests pass (actual commands, real output)
- [ ] Structured logs include Effect.fn spans and annotateLogs annotations
- [ ] `npx tsc --noEmit` — zero errors
- [ ] `npx effect-language-service quickfixes --project tsconfig.json` — zero diagnostics
- [ ] No regressions in existing test suite
- [ ] Feature works as documented (--help, error cases, happy path)

---

## Why Phase 5 Exists

Tests prove correctness in isolation. Phase 5 proves it works when composed into the real application.

Common things that pass tests but fail at runtime:
- Missing Layer in AppLayer composition (ELS catches this, but verify)
- Import path errors (ESM resolution differs from tsc)
- Platform-specific behavior (filesystem paths, command availability)
- Error boundary mapping producing wrong exit codes
- Structured logs missing annotations (Effect.fn not wired into tracing pipeline)

---

## Step 1: CLI Smoke Tests

Run actual CLI commands and verify output:

```bash
# Help text (verifies command is wired)
nix develop -c pnpm exec f3 <command> --help
# Expected: exits 0, shows all args/options

# Error case (verifies error boundary)
nix develop -c pnpm exec f3 <command> <invalid-input>
# Expected: exits with correct error code, meaningful message

# Happy path (if safe to run)
nix develop -c pnpm exec f3 <command> --dry-run <valid-input>
# Expected: produces expected output, no crashes
```

### What to Check

| Aspect | How |
|--------|-----|
| Command registered | `--help` exits 0 |
| Args/options parsed | `--help` shows all expected flags |
| Error boundary works | Invalid input → correct error type → correct exit code |
| Happy path works | Valid input → expected output |
| Dry run works | `--dry-run` produces plan without side effects |

---

## Step 2: Structured Log Verification

Verify that Effect.fn spans and annotateLogs annotations appear in output:

```bash
# Run with debug logging
LOG_LEVEL=debug nix develop -c pnpm exec f3 <command> <args> 2>&1 | head -50
```

Look for:
- `service=ServiceName` annotations from `Effect.annotateLogs`
- Span names matching `Effect.fn("ServiceName.method")` patterns
- Structured JSON log entries (not raw console.log)

If the application doesn't have a log transport configured, this step documents that gap for future work (not a blocker).

---

## Step 3: Full Gate Verification

Run all gates in sequence:

```bash
# TypeScript
nix develop -c npx tsc -p tsconfig.json --noEmit

# Effect Language Service
nix develop -c npx effect-language-service quickfixes --project tsconfig.json

# All tests
nix develop -c npx vitest run

# Coverage (if configured in Phase 4)
nix develop -c npx vitest run --coverage
```

Every command must pass. Zero errors, zero diagnostics, all tests green.

---

## Step 4: Regression Check

Verify that changes made in Phases 1-4 didn't break anything else:

```bash
# Run full test suite (not just new tests)
nix develop -c npx vitest run

# Run any existing integration tests
nix develop -c pnpm test
```

If any pre-existing test fails, the Phase 1-4 changes introduced a regression. Fix it before shipping.

---

## Anti-Patterns

- Skipping smoke tests because "tests pass" — runtime composition is different from test isolation
- Not checking error exit codes — `echo $?` after each command
- Assuming structured logs work without verifying — the tracing pipeline might not be configured
- Shipping without running the full existing test suite — regressions hide in unrelated tests
