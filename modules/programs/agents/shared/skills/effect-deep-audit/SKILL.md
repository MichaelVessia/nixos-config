---
name: effect-deep-audit
description: "Deep audit of an Effect-TS codebase against actual Effect core team patterns. Produces a tiered finding list + executable DAG plan, then systematically rewrites non-idiomatic code. USE THIS SKILL WHEN: 'audit this effect code', 'is this idiomatic effect', 'deep audit', starting a new Effect project and want to verify patterns, refactoring an Effect codebase toward library-grade quality, reviewing code before it ships to production. NOT FOR: Greenfield Effect projects (use effect-best-practices skill)."
version: 1.0.0
---

# Effect Deep Audit

Systematic methodology for bringing an Effect codebase to library-grade quality,
battle-tested across full-stack audits covering auth, middleware, schemas, repos,
event handlers, API groups, and tests.

## Prerequisites (Optional)

- **Effect source** (recommended): `git clone https://github.com/Effect-TS/effect` for pattern verification
- **Effect MCP**: https://github.com/tim-smart/effect-mcp for API lookups (fallback: https://effect.website/docs)

## The Process

### Phase 1: Reconnaissance (DO THIS FIRST)

**Verify against Effect source, not docs.** Docs lag. Source is truth.

```bash
# Clone Effect source for pattern verification (if not already done)
# git clone https://github.com/Effect-TS/effect <effect-repo>

# Service patterns
rg "class .* extends Context\.Tag" <effect-repo>/packages/platform/src
rg "Effect\.Service" <effect-repo>/packages/cluster/src

# Error patterns
rg "Schema\.TaggedError" <effect-repo>/packages/cluster/src

# Layer composition
rg "Layer\.provideMerge" <effect-repo>/packages/platform/src

# HttpApi patterns
rg "HttpApiBuilder\.group" <effect-repo>/packages/platform/src
rg "HttpApiBuilder\.middleware" <effect-repo>/packages/platform/src
```

If you have effect-mcp configured, also use `effect_docs_search({ query: "..." })` for API concepts.

**Check what your framework already provides.** Before writing custom code,
grep the framework source. This is consistently the highest-leverage finding
in audits — frameworks often provide operations that hundreds of lines of
custom code reimplement.

```bash
# Example: check what capabilities your framework's plugins provide
rg "api\." <framework-source>/src/plugins/<plugin-name>/
```

### Phase 2: Tiered Finding Classification

Audit every file in the target. Classify each finding:

| Tier | Tag | What | Priority |
|------|-----|------|----------|
| 0 | `BUG` | Code that doesn't execute or produces wrong results | Fix immediately |
| 1 | `PERF` | Unnecessary work (double resolution, N+1, redundant queries) | Fix in same pass |
| 2 | `SCHEMA` | Manual mappers, hand-written schemas that mirror tables, `as` casts | High — schema drift is a bug factory |
| 3 | `ARCH` | Monolith files, duplicated helpers, wrong abstraction boundaries | Medium — affects velocity |
| 4 | `IDIOM` | Non-idiomatic but correct (`DateTime.unsafeNow`, missing spans, `process.env`) | Low — clean up after structural work |
| 5 | `FINE` | Confirmed correct. Document why to prevent future "fixes" | N/A |

**Specific patterns to grep for:**

```bash
# Tier 0: Bugs
rg "Effect\.log(Error|Warning|Info)\(" --type ts  # statement expressions (Effect not chained)
rg "as any" --type ts                              # type escapes hiding real errors

# Tier 1: Sync I/O violations (breaks testability, blocks event loop)
rg "from 'node:fs'" --type ts                      # sync fs imports (should use FileSystem.FileSystem)
rg "from 'node:child_process'" --type ts           # sync exec imports (should use shell service or Command)
rg "existsSync|readFileSync|writeFileSync|mkdirSync|readdirSync|statSync|symlinkSync" --type ts
rg "execSync" --type ts                            # blocks event loop, not mockable

# Tier 2: Schema anti-patterns
rg "toModel|toXxx|toPublic" --type ts              # manual row mappers
rg "S\.Struct\({" --type ts                        # hand-written schemas (should be createSelectSchema)
rg "satisfies.*Schema" --type ts                   # schema-adjacent type assertions

# Tier 2: Error modeling
rg "Schema\.TaggedError" --type ts                 # check error patterns are correct
rg "catchAll\(\(\) =>" --type ts                   # blanket error suppression (should be catchTag or selective)
rg "Effect\.catch\(\(\)" --type ts                 # same pattern, different spelling

# Tier 3: Architecture
wc -l src/**/*.ts | sort -n | tail -10             # monolith files (>200 LOC)
rg "catchTag|catchTags|mapError" --type ts -c      # duplicated error handling

# Tier 4: Idioms
rg "DateTime\.unsafeNow" --type ts                 # should be DateTime.now (effectful)
rg "process\.env" --type ts                        # should use Config/Layer
rg "Effect\.sync.*unsafe" --type ts                # unnecessary sync wrapper
rg "withSpan" --type ts -c                         # span coverage (should be everywhere)
rg "const [A-Z_]+ = ['\"]" src/ --type ts          # hardcoded string constants (candidates for Config)
rg "const [A-Z_]+ = \d+" src/ --type ts            # hardcoded number constants (candidates for Config)
```

### Phase 3: Plan as DAG

Structure the plan as a dependency graph. Key insight:
**type errors cascade.** Changing a schema breaks every consumer. Changing a service
interface breaks every implementation. Work bottom-up:

```
Layer 0: Foundation (schemas, table defs, branded types)
Layer 1: Service interfaces + middleware
Layer 2: Implementations (repos, event handlers)
Layer 3: API handlers (group files)
Layer 4: Tests
Layer 5: Cleanup (spans, idioms, dead code)
```

Each layer gates on: 0 type errors + all tests passing. Do NOT proceed to the
next layer with errors. The type checker is your friend — it tells you every
callsite that needs updating.

### Phase 4: Execution

**Parallelize mechanical work.** Schema renames, import fixes, field renames across
20 files — these are perfect for parallel agents. Save judgment-heavy work for
files that require it (handler rewrites, middleware logic, layer composition).

**Keep tests green.** Run `tsc --noEmit` + `vitest run` after EVERY structural
change. If you have 14 errors, fix all 14 before moving on. Compounding errors
across layers is how 3-hour debugging sessions happen.

**Delete aggressively.** No backwards compat shims. No renamed `_unused` vars. No
`// removed` comments. If code is dead, `rm` it. Git has history.

## Key Patterns Discovered

### createSelectSchema = sole schema source of truth

Every API response schema derives from a Drizzle table:

```typescript
import { createSelectSchema } from 'drizzle-orm/effect-schema'

const OwnedAssetSelect = createSelectSchema(ownedAssets, {
  id: OwnedAssetId,           // branded type override
  ownerUserId: UserId,        // branded type override
  kind: OwnedAssetKind,       // literal union override
  createdAt: Schema.DateTimeUtc,  // NOT DateTimeUtcFromDate (breaks HTTP JSON)
}).omit('metadata', 'sourceEventId')
```

**Critical:** Use `Schema.DateTimeUtc` (Encoded=string), NOT `Schema.DateTimeUtcFromDate`
(Encoded=Date). DateTimeUtcFromDate breaks HTTP JSON round-trips because the encoded
form is a Date object, not a string. This bug was found in multiple domain packages
during audits.

**Nullable columns with overrides need `S.NullOr()` wrapping** — the override replaces
the full column schema including auto-nullability.

Handlers decode inline — no mapper functions:
```typescript
return yield* S.decodeUnknown(MySchema)(row).pipe(Effect.orDie)
```

### Single middleware pattern

One middleware that: resolves session, checks authorization, provides context.
Not two middlewares where the second re-resolves what the first already resolved.

### Effect.logError is an Effect, not a statement

```typescript
// BUG: creates Effect value, discards it
Effect.logError('something broke', { error })
return Effect.succeed(fallbackResponse)

// FIX: chain it
Effect.logError('something broke', { error }).pipe(
  Effect.as(fallbackResponse)
)
```

### Tracing

- Use `Effect.fn("Service.method")` for service method definitions (preferred — combines function definition + automatic span)
- Use `Effect.withSpan` only when wrapping existing effects in pipe chains
- Add `Effect.annotateLogs("service", "ServiceName")` to every service module

```typescript
// Preferred: Effect.fn for service methods
findById: Effect.fn("UserRepository.findById")(function*(userId) {
  const rows = yield* sql`SELECT * FROM users WHERE id = ${userId}`
  if (rows.length === 0) return yield* new UserNotFound({ userId })
  return yield* Schema.decodeUnknown(User)(rows[0])
}),

// Fallback: withSpan for pipe chains
listByOwner: (userId, limit = 100) =>
  db.select().from(table).where(...).pipe(
    Effect.mapError(toRepositoryQueryError(REPO, 'listByOwner')),
    Effect.flatMap(Effect.forEach((row) => decode(row).pipe(Effect.orDie))),
    Effect.withSpan('OwnedAssetRepository.listByOwner'),
  ),
```

### Monolith handler files -> one file per API group

A 500-line handler file with all routes is unnavigable. Split into:
- `groups/HealthGroupLive.ts`
- `groups/AdminGroupLive.ts`
- `groups/UserManagementGroupLive.ts`
- etc.

The main handler file becomes pure layer wiring (~30-50 lines).

Shared error helpers go in a dedicated module, not duplicated
across group files.

### DateTime.now vs DateTime.unsafeNow

`DateTime.unsafeNow()` is sync. `DateTime.now` is effectful. In Effect.gen
contexts, always use `yield* DateTime.now`. The "unsafe" prefix exists for
a reason — it bypasses the Effect runtime's clock, which matters for testing
and time-travel debugging.

## Checklist (run after every audit)

```
[ ] Every API response schema uses createSelectSchema, not manual S.Struct
[ ] Every DateTimeUtc column uses S.DateTimeUtc (not DateTimeUtcFromDate)
[ ] Every nullable column with a branded override uses S.NullOr()
[ ] No toXxx mapper functions — handlers decode inline with S.decodeUnknown
[ ] No as any / as unknown type escapes in non-test code
[ ] No Effect.logError/logWarning as statement expressions
[ ] No process.env — all config through Effect Config/Layer
[ ] No DateTime.unsafeNow in Effect.gen contexts
[ ] Every service method uses Effect.fn (or Effect.withSpan for pipe chains)
[ ] Every service module has Effect.annotateLogs
[ ] No handler files > 200 LOC — split into per-group files
[ ] No duplicated error mapping helpers — extract to shared module
[ ] Tests split into per-group files with shared test infrastructure
[ ] Framework capabilities audited before writing custom code
[ ] Dead code deleted (not commented out, not renamed with _prefix)
[ ] No sync Node.js I/O — use FileSystem.FileSystem, not readFileSync/existsSync/etc.
[ ] No execSync — use Effect-tracked shell service or platform Command
[ ] No blanket catchAll error suppression — use catchTag or inspect error content
[ ] Tunable constants use Config with withDefault, not module-level consts
[ ] Test layers use FileSystem.layerNoop for I/O mocking, not real filesystem
```

## References

| Reference | Content |
|-----------|---------|
| `effect-best-practices` skill | Idiomatic Effect patterns (services, layers, errors) |
| Effect source | Grep here for real patterns, not docs — `git clone https://github.com/Effect-TS/effect` |
