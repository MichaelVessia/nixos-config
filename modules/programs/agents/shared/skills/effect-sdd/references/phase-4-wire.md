# Phase 4: Wire

## Gate (must pass to ship)

- [ ] All previous phase tests still pass
- [ ] CLI/API boundary tests pass
- [ ] Error boundary mapping verified (every domain error → exit code)
- [ ] `npx effect-language-service quickfixes --project tsconfig.json` — zero diagnostics
- [ ] Branch coverage: 100% domain, 90%+ boundary
- [ ] `npx vitest run --coverage`

---

## Why Orchestrator Executes Phase 4

Phase 4 is typically handled by the orchestrator, though agents CAN execute it with sufficient context. Key considerations:
1. CLI wiring crosses module boundaries (command handler + error mapping + Layer composition)
2. Error architecture is global (F3Error union, exitCodeFor, catchTag chains)
3. Agents need context about the full error boundary — provide it explicitly if delegating

---

## Step 1: Layer Composition

Add service layers to the application's root layer:

```typescript
// bin/app.ts
import { PromotionPipelineLive } from "../src/services/promote/index.js"

const AppLayer = Layer.mergeAll(
  // ...existing services...
  PromotionPipelineLive,  // provides all 6 leaf services
).pipe(
  Layer.provideMerge(SharedDepsLive),
  Layer.provideMerge(NodeContext.layer)
)
```

Effect's layer system handles transitive dependencies (FileSystem, Path, CommandExecutor come from downstream layers).

---

## Step 2: Error Boundary Mapping

Domain errors stay in their module. The command handler maps them to application-level errors via `catchTag`:

```typescript
const promoteCommand = Command.make("promote", { ... }, (args) =>
  Effect.gen(function*() {
    // ... command logic ...
  }).pipe(
    // Map domain errors → application errors at the boundary
    Effect.catchTag("IngestNotFoundError", (e) =>
      Effect.fail(new InvalidInputError({ message: e.message }))
    ),
    Effect.catchTag("PackageAnalysisError", (e) =>
      Effect.fail(new FileIOError({ message: e.message, path: e.packagePath, operation: "analyze" }))
    ),
  )
)
```

### Error Channel Analysis (CRITICAL)

**Before writing catchTag chains**, analyze the pipeline's inferred error type. You can only catch errors that actually appear in the channel:

```typescript
// The promote() function's error channel is INFERRED:
// IngestNotFoundError | PackageAnalysisError | ImportRewriteError | PromotionError

// DependencyConflictError is NOT in the channel (conflicts are collected as data)
// Catching it would be a type error!
```

If `catchTag("X", ...)` fails with a type error, X is not in the error channel. Don't force it — the type system is telling you something.

---

## Step 3: Boundary Tests

```typescript
// test/commands/promote.test.ts
import { describe, it, expect } from "@effect/vitest"

describe("promote error boundary", () => {

  it.effect("IngestNotFoundError maps to InvalidInputError", () =>
    Effect.gen(function*() {
      const result = yield* promoteEffect.pipe(
        Effect.provide(NotFoundLayer),
        Effect.either
      )
      expect(result._tag).toBe("Left")
      if (result._tag === "Left") {
        expect(result.left._tag).toBe("InvalidInputError")
      }
    })
  )

  it.effect("PackageAnalysisError maps to FileIOError", () =>
    // ...
  )
})
```

---

## Step 4: Integration Tests

Test actual CLI invocation where practical:

```typescript
describe("CLI integration", () => {

  it.effect("promote --help exits 0", () =>
    Effect.gen(function*() {
      const cmd = PlatformCommand.make("bun", "bin/app.ts", "promote", "--help")
      const code = yield* PlatformCommand.exitCode(cmd)
      expect(code).toBe(0)
    })
  )

  it.effect("promote nonexistent exits 2", () =>
    Effect.gen(function*() {
      const cmd = PlatformCommand.make("bun", "bin/app.ts", "promote", "nonexistent", "dest")
      const code = yield* PlatformCommand.exitCode(cmd)
      expect(code).toBe(2)  // InvalidInputError → exit 2
    })
  )
})
```

---

## Step 5: Coverage Gate

```bash
# Run coverage with branch threshold
npx vitest run --coverage --coverage.branches=100

# Or configure in vitest.config.ts:
export default {
  test: {
    coverage: {
      provider: 'v8',
      branches: 100,      // domain code
      functions: 95,
      lines: 95,
      statements: 95,
      include: ['src/**'],
      exclude: ['src/**/*.test.*', 'bin/**']
    }
  }
}
```

**Branch coverage is the metric.** It catches:
- `catchTag` both success and error paths
- `Match.exhaustive` all arms
- `Option.match` Some/None
- `Effect.either` Left/Right

---

## Variant: Error-as-Data Boundary

Some orchestrators catch all leaf errors internally (via `Effect.either`) and convert them to data. In this case, the command boundary is simpler — no catchTag chain needed.

```typescript
// HealthAudit catches all errors internally → HealthReport (data)
// Command just checks the report:
if (report.overall === "error") {
  return yield* new DiagnosticsFoundError({ count: errorCount, message: "..." })
}
```

**When this applies:**
- Orchestrator wraps leaf calls in `Effect.either` and converts errors to data
- No domain errors reach the command handler
- Boundary test verifies DATA content (report fields), not error propagation
- Single error type at command level (e.g., DiagnosticsFoundError)

**Boundary tests for error-as-data:**
- Test report with `overall === "ok"` → command succeeds
- Test report with `overall === "error"` → correct error type + count
- Test that `overall === "warn"` doesn't trigger error (if applicable)
- Test error count accuracy (only severity=error, not warn/ok)

---

## Anti-Patterns

- `catchTag` for errors not in the channel — analyze the inferred error type first
- Skipping error boundary tests — the mapping chain is critical correctness logic
- Line coverage instead of branch coverage — line coverage misses conditionals
- Missing PromotionPipelineLive in AppLayer — ELS catches this: "Missing X in expected Effect context"
- `require()` in test files — ESM only, use static imports
