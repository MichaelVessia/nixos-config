# Testing Strategy

Cross-cutting reference for all phases. The SDD testing approach is a gradient — testing increases monotonically, never decreases.

---

## Three-Tier Property Testing (Slatton)

In decreasing verification power:

### Tier 1: Reference-Model Testing (Strongest)

Compare real implementation against a simple reference. The reference is often the Phase 2 Layer.mock stub.

```typescript
// Same operation, two layers, compare results
const op = Users.pipe(Effect.flatMap(u => u.findById(testId)))

const refResult = await Effect.runPromise(op.pipe(Effect.provide(MockLayer), Effect.either))
const realResult = await Effect.runPromise(op.pipe(Effect.provide(RealLayer), Effect.either))

expect(realResult._tag).toBe(refResult._tag)
```

**Effect's Layer system makes this trivial.** Same test, swap the layer. The Phase 2 mocks ARE the reference model.

### Tier 2: Invariant Testing

Properties that must always hold regardless of input:

```typescript
it.effect.prop(
  "promotion with N source files produces N file moves",
  { files: Schema.NonEmptyArray(FilePath) },
  ({ files }) =>
    Effect.gen(function*() {
      const plan = yield* buildPlan(infoWith(files), target, "promote", [])
      expect(plan.fileMoves.length).toBe(files.length)
    }).pipe(Effect.provide(MockLayer))
)
```

**Algebraic properties:**
- **Idempotency**: `classify(x)` twice gives the same result
- **Commutativity**: merging plans A+B = B+A (if applicable)
- **Associativity**: (A+B)+C = A+(B+C)
- **Identity**: promoting with zero files = no-op

### Tier 3: Crash Testing (Broadest Coverage)

Random valid inputs → assert no throws, only Effect errors:

```typescript
it.effect.prop(
  "analyzer never throws on valid input",
  { name: IngestName, sub: Schema.String },
  ({ name, sub }) =>
    Effect.gen(function*() {
      const analyzer = yield* PackageAnalyzer
      const result = yield* analyzer.analyze(name, sub).pipe(Effect.either)
      // Either success or tagged error — never a throw
      expect(result).toBeDefined()
    }).pipe(Effect.provide(RealLayer))
)
```

**Corrupted input crash testing:**

```typescript
it.prop("User.decode handles corrupted input cleanly", [User], (user) => {
  const encoded = Schema.encodeSync(User)(user)
  const corrupted = { ...encoded, name: 42, email: null }
  const result = Schema.decodeUnknownEither(User)(corrupted)
  // Clean Either.Left, never throws
  expect(result._tag).toBe("Left")
})
```

---

## @effect/vitest API

### Test Contexts

| API | Clock | Platform | Use When |
|-----|-------|----------|----------|
| `it.effect` | Test clock | Test platform | Default — most tests |
| `it.live` | Real clock | Real platform | Tests needing real timing/FS |
| `it.layer(L)` | Test clock | Via layer | Scoped suite with shared layer |

Evaluate per test suite which context is needed.

### Property Testing

**Prefer record-style** `{ name: Schema }` over array `[Schema]`. Array form wraps values in a tuple — the callback arg type may not match expectations.

```typescript
// PREFERRED: Record style — named destructuring, clean types
it.prop("name", { s: Schema.String, n: Schema.Int }, ({ s, n }) => {
  expect(typeof s).toBe("string")
})

// Effectful property test (record style)
it.effect.prop("name", { userId: UserId, eventId: EventId }, ({ userId, eventId }) =>
  Effect.gen(function*() {
    const result = yield* someOp(userId, eventId)
    expect(result).toBeDefined()
  })
)

// Array style works but types can be surprising with tuples
it.prop("name", [Schema.String, Schema.Int], ([s, n]) => {
  expect(typeof s).toBe("string")
})

// fast-check configuration
it.effect.prop("name", { v: Schema }, ({ v }) => Effect.void, {
  fastCheck: { numRuns: 1000, seed: 42 }
})
```

### Schema.Arbitrary

```typescript
import { Arbitrary, FastCheck } from "effect"

// Generate arbitrary instances from any schema
const arbUser = Arbitrary.make(User)
FastCheck.sample(arbUser, 10)  // 10 random valid Users

// Schemas with constraints generate constrained values
const arbName = Arbitrary.make(Schema.NonEmptyString.pipe(Schema.maxLength(20)))
// All generated strings: 1-20 chars, never empty

// Custom arbitrary generation via annotations
const CustomName = Schema.NonEmptyString.annotations({
  arbitrary: () => (fc) => fc.constantFrom("Alice", "Bob", "Charlie")
})
```

### fast-check from Effect

```typescript
import { FastCheck } from "effect"
// or
import * as fc from "effect/FastCheck"

// Full fast-check API available — no separate dependency
fc.assert(fc.property(Arbitrary.make(User), (user) => {
  // ...
}))
```

---

## Coverage Targets

| Scope | Branch | Lines | Functions |
|-------|--------|-------|-----------|
| Domain models (schemas, services) | 100% | 95% | 100% |
| Orchestrators | 100% | 95% | 100% |
| CLI/API boundary | 90% | 85% | 90% |
| Pure helpers | 100% | 95% | 100% |

**Branch coverage is the primary metric.** It catches:
- `if/else` both paths
- `catchTag` success and error
- `Match.exhaustive` all arms exercised
- `Option.match` Some and None
- `Effect.either` Left and Right

---

## Testing Gradient by Phase

| Phase | New tests added |
|-------|----------------|
| 1 Model | Schema roundtrips, branded type invariants, algebraic properties, crash tests |
| 2 Validate | Orchestration happy/error paths, orchestration-level property tests |
| 3 Implement | Contract tests (real layers), reference-model tests, pure helper unit tests |
| 4 Wire | Error boundary mapping, CLI integration, coverage gate |

**Tests from earlier phases ALWAYS still pass.** If a Phase 3 change breaks Phase 1 property tests, the implementation is wrong — not the test.

---

## Anti-Patterns

- Bun scripts with `console.log("PASS")` — always @effect/vitest
- `Layer.succeed` when `Layer.mock` would catch untested paths
- Testing implementation details instead of behavior
- Line coverage as the metric — use branch coverage
- Deferring property tests to "later" — they belong in Phase 1
- Skipping crash tests — random input finds bugs humans never think of
- Tests that only run against mocks, never against real layers — reference-model tests bridge this
