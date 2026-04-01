---
name: effect-deslopify-idiomatic
description: "Audit and remediate Effect code to idiomatic standards. Chains effect-sdd audit methodology with Effect best practices to systematically identify and fix non-idiomatic patterns. USE THIS SKILL WHEN: 'deslopify', 'make this idiomatic effect', 'audit effect quality', 'is this good effect code', 'library-grade effect'."
version: 1.0.0
---

# Effect Deslopify (Idiomatic Remediation)

Systematic audit and remediation of Effect-TS code to library-grade idiomatic standards.

Companion skills: `effect-best-practices` (pattern reference), `effect-sdd` (methodology). These provide the pattern reference and methodology this skill orchestrates.

## Target

Apply to any Effect-TS codebase, package, or file path.

## Mission

- De-slopify the target
- Make code library-grade idiomatic Effect
- Keep behavior stable unless fixing a confirmed bug

## Workflow

### 1. Audit (SDD Phases 1-4)

Run SDD audit mode across phases 1-4 on the target.

### 2. Gap Analysis

Produce a gap list covering:
- Schema modeling (bare brands, missing constraints, manual mappers)
- Service boundaries (wrong abstraction level, god services)
- Error channels (silent swallowing, wrong error types, blanket catchAll)
- Layer wiring (missing deps, provide vs provideMerge)
- Purity violations (impure ops outside Effect tracking)
- **Sync I/O violations** (`readFileSync`, `existsSync`, `execSync`, etc. instead of Effect platform services)
- **Hardcoded tunables** (module-level constants that should use `Config`)
- Exhaustiveness (switch instead of Match.exhaustive)
- Test coverage (missing property tests, bun scripts)
- **Test mockability** (services using sync Node.js APIs can't be mocked with `FileSystem.layerNoop`)

### 3. Decide: Remediate or Rewrite

For each gap:
- **Remediate** if architecture is sound and gaps are localized
- **Rewrite** only if architecture is unsalvageable (majority of phases FAIL)

### 4. Implement Fixes

Implement highest-impact fixes. Priority order:
1. Bugs (incorrect behavior, discarded Effect values)
2. Schema constraints (bare brands, missing validation)
3. Error modeling (Data.TaggedError -> Schema.TaggedError)
4. Service patterns (Effect.fn, annotateLogs)
5. Test gaps (property tests, vitest conversion)

### 5. Regression Tests

Add/keep regression tests for bug fixes (TDD: failing test first, then fix).

### 6. Verify Gates

Run all applicable gates:
- Your project's typecheck command (e.g. `npx tsc --noEmit` or `pnpm check`)
- `npx effect-language-service quickfixes --project tsconfig.json` (if configured)
- Relevant test suites

## Idiomatic Constraints

These are non-negotiable for library-grade Effect code:

| Constraint | Why |
|-----------|-----|
| No `as any` | Type escapes hide real errors |
| No silent `catchAll` error swallowing | Errors must be logged or propagated; use `catchTag` or inspect error content for selective recovery |
| No raw `fetch` when typed client exists | Duplicating URLs loses type safety |
| No ad-hoc mutable state in Effect paths | Use `Ref` for tracked state |
| Impure ops wrapped in `Effect.sync` / Effect APIs | Effect must track all side effects |
| **No sync Node.js I/O** (`readFileSync`, `existsSync`, `execSync`, etc.) | Use `FileSystem.FileSystem` or an Effect-tracked shell service; sync calls break testability and block the event loop |
| **Tunable constants use `Config`** | Hardcoded org names, timeouts, concurrency limits should use `Config.string`/`Config.number` with `Config.withDefault` for env-var overridability |
| `Match.exhaustive` not `switch` | Compile-time case coverage |
| Errors modeled explicitly | `Schema.TaggedError` with typed channels |
| `Effect.fn` on all service methods | Automatic tracing spans |
| `Effect.annotateLogs` per service module | Structured observability |
| `yield* new TaggedError()` in generators | Not `Effect.fail(new TaggedError())` |
| **Test layers use `FileSystem.layerNoop`** | Not real filesystem; enables isolated, fast, deterministic tests |

## Before / After Examples

### Bare Brand -> Constrained Brand

```typescript
// BEFORE (sloppy): accepts empty strings, whitespace, anything
const UserId = Schema.String.pipe(Schema.brand("UserId"))

// AFTER (idiomatic): enforces domain invariants
const UserId = Schema.NonEmptyString.pipe(
  Schema.pattern(/^usr_[a-z0-9]+$/),
  Schema.brand("UserId")
)
```

### Manual Tracing -> Effect.fn

```typescript
// BEFORE (sloppy): manual withSpan, no argument capture
findById: (id: UserId) =>
  sql`SELECT * FROM users WHERE id = ${id}`.pipe(
    Effect.flatMap(rows => decode(rows[0])),
    Effect.withSpan("UserRepo.findById"),
  ),

// AFTER (idiomatic): Effect.fn captures args + creates span
findById: Effect.fn("UserRepo.findById")(function*(id: UserId) {
  const rows = yield* sql`SELECT * FROM users WHERE id = ${id}`
  if (rows.length === 0) return yield* new UserNotFound({ userId: id })
  return yield* Schema.decodeUnknown(User)(rows[0])
}),
```

### Silent Error Swallowing -> Explicit Handling

```typescript
// BEFORE (sloppy): error silently disappears
const result = yield* dangerousOp.pipe(
  Effect.catchAll(() => Effect.succeed(fallback))
)

// AFTER (idiomatic): error logged before fallback
const result = yield* dangerousOp.pipe(
  Effect.tapError((e) => Effect.logWarning("Falling back", { error: e })),
  Effect.catchAll(() => Effect.succeed(fallback))
)
```

## Output

After running deslopify, report:
- Changed files (with summary of what changed)
- Anti-patterns removed (count by category)
- Test/gate results (pass/fail)
- Residual risks + follow-ups (anything not fixed in this pass)
