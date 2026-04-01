# Phase 3: Implement

## Gate (must pass before Phase 4)

- [ ] All Phase 1 property tests still pass
- [ ] All Phase 2 orchestration tests still pass (they're layer-independent)
- [ ] Contract tests pass against real Layer implementations
- [ ] Reference-model tests pass (Layer.mock vs real Layer comparison)
- [ ] `npx effect-language-service quickfixes --project tsconfig.json` — zero diagnostics
- [ ] Every service method uses `Effect.fn` for tracing
- [ ] Every service has `Effect.annotateLogs` for structured observability

---

## Step 1: Split Into Modules

**Mechanical transformation — no logic changes.** The sketch becomes a module tree:

```
src/
  models.ts          # Schema.Class models + branded IDs
  errors.ts          # Schema.TaggedError definitions
  services.ts        # Context.Tag interfaces (re-exported)
  services/
    Users.ts         # Context.Tag + UsersLive (Layer.effect)
    Tickets.ts       # Context.Tag + TicketsLive
    Emails.ts        # Context.Tag + EmailsLive
    Registration.ts  # Orchestrator (import services)
  index.ts           # Barrel exports
```

Split rules:
- `models.ts` and `errors.ts` have NO circular imports
- Each service file exports both the Tag AND the Live layer
- Orchestrator imports service Tags, not implementations

---

## Step 2: Real Layer Implementations

```typescript
// services/Users.ts
import { Layer, Effect } from "effect"
import { SqlClient } from "@effect/sql"
import { Users } from "../services.js"
import { User, UserNotFound } from "../models.js"

const annotate = Effect.annotateLogs("service", "Users")

export const UsersLive = Layer.effect(
  Users,
  Effect.gen(function*() {
    const sql = yield* SqlClient.SqlClient

    return {
      findById: Effect.fn("Users.findById")(function*(id) {
        const rows = yield* sql`SELECT * FROM users WHERE id = ${id}`
        if (rows.length === 0) return yield* new UserNotFound({ userId: id })
        return yield* Schema.decodeUnknown(User)(rows[0])
      }),
    }
  })
)
```

### Implementation Checklist

For EVERY service method:
- [ ] Wrapped in `Effect.fn("ServiceName.methodName")` for tracing
- [ ] Module-level `const annotate = Effect.annotateLogs("service", "ServiceName")`
- [ ] Real I/O uses @effect/platform (FileSystem, Path, Command) or @effect/sql
- [ ] Errors are domain errors (Schema.TaggedError), not platform errors
- [ ] `yield* new TaggedError(...)` — NOT `yield* Effect.fail(new TaggedError(...))`

---

## Step 3: Contract Tests

**Same tests, different layer.** Phase 2 tests ran against Layer.mock. Now run equivalent tests against real layers.

```typescript
// test/services/Users.test.ts
import { describe, it } from "@effect/vitest"

// Real layer (needs database/platform)
const RealLayer = UsersLive.pipe(
  Layer.provide(SqlLive),  // or mock SQL if needed
  Layer.provide(NodeContext.layer)
)

describe("Users contract", () => {

  it.effect("findById returns user when exists", () =>
    Effect.gen(function*() {
      const users = yield* Users
      // seed test data first...
      const user = yield* users.findById(testUserId)
      expect(user.id).toBe(testUserId)
    }).pipe(Effect.provide(RealLayer))
  )

  it.effect("findById fails with UserNotFound when missing", () =>
    Effect.gen(function*() {
      const users = yield* Users
      const result = yield* users.findById(missingId).pipe(Effect.either)
      expect(result._tag).toBe("Left")
    }).pipe(Effect.provide(RealLayer))
  )
})
```

### Only Mock IO (Slatton Rule)

| Service type | Test with |
|-------------|-----------|
| Pure computation (severity mapping, path rewriting) | Real implementation directly |
| I/O (filesystem, network, database) | Layer.mock for IO deps, real for logic |
| External API (email, payment) | Layer.mock for the API client |

---

## Step 4: Reference-Model Tests

**The most powerful test pattern.** Run identical operations against both layers, compare results.

```typescript
describe("Users reference-model", () => {

  it.effect("findById matches reference behavior", () =>
    Effect.gen(function*() {
      const testId = UserId.make("usr-test-1")

      // Reference (Phase 2 mock)
      const refResult = yield* Effect.provide(
        Users.pipe(Effect.flatMap(u => u.findById(testId))),
        MockLayer
      ).pipe(Effect.either)

      // Real implementation
      const realResult = yield* Effect.provide(
        Users.pipe(Effect.flatMap(u => u.findById(testId))),
        RealLayer
      ).pipe(Effect.either)

      // Same behavior
      expect(realResult._tag).toBe(refResult._tag)
      if (realResult._tag === "Right" && refResult._tag === "Right") {
        expect(realResult.right.id).toBe(refResult.right.id)
      }
    })
  )
})
```

Effect's Layer system makes this trivial — same test function, swap the provided layer.

---

## Step 5: Unit Tests for Pure Helpers

Functions that don't need layers get direct unit tests:

```typescript
describe("severity mapping", () => {
  it("missing required dep is error", () => {
    expect(depSeverity({ status: "missing", required: true })).toBe("error")
  })

  it("outdated dep is warn", () => {
    expect(depSeverity({ status: "outdated", required: false })).toBe("warn")
  })
})
```

---

## Agent Dispatch (Optional)

If Phase 3 is delegated to sub-agents, the sketch IS the spec:

```
Implement the {ServiceName} service.

## Interface
{Context.Tag definition from sketch}

## Domain Types
{Schema.Class and TaggedError definitions}

## Requirements
- Effect.fn on every method
- Effect.annotateLogs module-level
- yield* TaggedError (not Effect.fail)
- Export {ServiceName}Live as a Layer

## Validation
Contract tests in test/services/{ServiceName}.test.ts must pass.
```

Each leaf service = one agent task. Orchestrator validates output.

---

## Step 6: Cleanup

- [ ] Delete old bun test scripts (`_test.ts`, `_test.bun.ts`, etc.) — vitest replacements exist
- [ ] Export pure helpers for independent unit testing (parsers, mappers, validators)
- [ ] Verify no `require()` calls in test files — ESM only, use static imports

---

## Anti-Patterns

- Implementing without reading the sketch — the sketch IS the spec
- `process.cwd()` instead of RepoRoot service — always use provided services
- Circular imports between models/errors/services — keep the DAG clean
- Duplicate module structure (both `domain.ts` and split `models.ts + errors.ts`) — pick one
- Forgetting Effect.fn / annotateLogs — mandatory for observability
- `Effect.fail(new TaggedError(...))` in generators — TaggedErrors are yieldable, just `yield* new TaggedError(...)`. NOTE: `Effect.fail(new TaggedError(...))` IS correct inside `flatMap`/`map`/pipe chains where `yield*` is unavailable
- `require()` in test files — always use ESM static imports
- Leaving dead bun test scripts after vitest conversion — delete them in this phase
