# Phase 1: Model

## Gate (must pass before Phase 1.5)

- [ ] `npx tsc --noEmit` — zero errors
- [ ] `npx effect-language-service quickfixes --project tsconfig.json` — zero diagnostics
- [ ] All property tests pass in @effect/vitest
- [ ] Every Schema.Class has an encode/decode roundtrip test
- [ ] Every branded type has constraint validation
- [ ] Orchestrator typechecks with zero implementations

---

## What You Produce

1. **One `.sketch.ts` file** — domain models, errors, service interfaces, orchestrator
2. **One `.test.ts` file** — property tests co-designed with schemas

Both in the same directory. Both typecheck.

---

## Step 1: Schema Domain Models

**Pretend `interface` and `class` don't exist for data modeling. Only Schema exists.**

### Branded IDs with Constraints

Every branded type gets REAL constraints, not bare strings:

```typescript
// BAD — accepts empty strings, whitespace, anything
const UserId = Schema.String.pipe(Schema.brand("UserId"))

// GOOD — enforces domain invariants at the type level
const UserId = Schema.NonEmptyString.pipe(
  Schema.pattern(/^usr_[a-z0-9]{12}$/),
  Schema.brand("UserId")
)

const EventId = Schema.UUID.pipe(Schema.brand("EventId"))

const Email = Schema.NonEmptyString.pipe(
  Schema.pattern(/^[^@]+@[^@]+\.[^@]+$/),
  Schema.brand("Email")
)
```

### Constraint Checklist

For EVERY schema field, evaluate:

| Type | Ask | Options |
|------|-----|---------|
| String | Empty allowed? | `NonEmptyString`, `minLength(n)` |
| String | Format? | `pattern()`, `UUID`, `ULID`, `Trimmed` |
| String | Case? | `Lowercased`, `Uppercased`, `Capitalized` |
| Number | Integer? | `Int`, `JsonNumber` |
| Number | Range? | `Positive`, `NonNegative`, `between(min, max)` |
| Array | Empty allowed? | `NonEmptyArray(item)`, `minItems(n)` |
| Array | Max size? | `maxItems(n)` |
| Date | Range? | `betweenDate(min, max)` |

### Entities — Schema.Class for entities, Schema.Struct for DTOs/responses

Use `Schema.Class` when the type needs identity semantics (Equal/Hash), methods, or PrimaryKey.
Use `Schema.Struct` for plain data transfer objects and API responses.

```typescript
// Entity (needs identity/equality) — Schema.Class
class User extends Schema.Class<User>("User")({
  id: UserId,
  name: Schema.NonEmptyString.pipe(Schema.maxLength(100)),
  email: Email,
  createdAt: Schema.DateTimeUtc,
}) {}

// DTO/response (just data) — Schema.Struct
const UserSummary = Schema.Struct({
  id: UserId,
  name: Schema.NonEmptyString,
  email: Email,
})
type UserSummary = typeof UserSummary.Type
```

### Errors — Schema.TaggedError

```typescript
class UserNotFound extends Schema.TaggedError<UserNotFound>()("UserNotFound", {
  userId: UserId,
}) {}

// Yieldable: `yield* new UserNotFound(...)` — no Effect.fail needed
```

---

## Step 2: Property Tests (Co-Designed with Schemas)

**Write these WHILE defining schemas.** The tests drive the constraints.

```typescript
// test/domain.test.ts
import { describe, it } from "@effect/vitest"
import { Schema, FastCheck, Arbitrary } from "effect"

describe("domain model properties", () => {

  // Tier 1: Roundtrip (reference-model where reference = identity)
  it.prop("User encode/decode roundtrip", { user: User }, ({ user }) =>
    Effect.gen(function*() {
      const encoded = Schema.encodeSync(User)(user)
      const decoded = Schema.decodeSync(User)(encoded)
      expect(decoded).toEqual(user)
    })
  )

  // Tier 2: Invariant
  it.prop("UserId is never empty", { id: UserId }, ({ id }) =>
    Effect.sync(() => {
      expect(id.length).toBeGreaterThan(0)
    })
  )

  // Tier 2: Algebraic property
  it.prop("ClassifiedDep.classify is idempotent", { input: DepInput }, ({ input }) =>
    Effect.gen(function*() {
      const first = yield* classify(input)
      const second = yield* classify(input)
      expect(first).toEqual(second)
    })
  )

  // Tier 3: Crash test — random input doesn't throw
  it.prop("User.decode never throws on arbitrary encoded", { user: User }, ({ user }) =>
    Effect.sync(() => {
      const encoded = Schema.encodeSync(User)(user)
      // Corrupt it
      const corrupted = { ...encoded, name: 42 }
      // Should fail cleanly, not throw
      const result = Schema.decodeUnknownEither(User)(corrupted)
      // Either Left (clean error) or Right (somehow valid) — never throws
      expect(result).toBeDefined()
    })
  )
})
```

### What to Test

| Schema artifact | Required tests |
|----------------|---------------|
| Every `Schema.Class` | Encode/decode roundtrip |
| Every branded type | Constraint holds on generated values |
| Every `Schema.TaggedError` | Roundtrip + `_tag` is correct |
| Domain invariants | Algebraic properties (idempotency, commutativity, etc.) |
| Corrupted input | Decode returns Either.Left, never throws |

---

## Step 3: Service Interfaces (Context.Tag)

**Write the orchestrator FIRST, then extract the interfaces it needs.**

The orchestrator defines the "perfect DSL" for implementing itself. Don't design services independently — let them emerge from what the composition requires.

```typescript
// Write this first:
const registerForEvent = (eventId: EventId, userId: UserId) =>
  Effect.gen(function*() {
    const users = yield* Users       // <- these Tags don't exist yet
    const tickets = yield* Tickets
    const emails = yield* Emails

    const user = yield* users.findById(userId)
    const ticket = yield* tickets.issue(eventId, userId)
    yield* emails.send(user.email, "Confirmed", `Ticket: ${ticket.code}`)

    return new Registration({ user, ticket, confirmationSent: true })
  })

// Then extract the interfaces the orchestrator needs:
class Users extends Context.Tag("Users")<Users, {
  readonly findById: (id: UserId) => Effect.Effect<User, UserNotFound>
}>() {}
```

### Orchestrator Rules

1. **Minimum inline logic.** If >20 lines of computation, extract a service or a helper function.
2. **One responsibility.** The orchestrator composes. It doesn't compute.
3. **Every service yields exactly what the orchestrator needs.** No unnecessary abstractions.
4. **`Effect.fn` on ALL orchestrators** — not just service methods. This is where you diagnose production issues.
5. **Use `Effect.all` for independent operations** — e.g., `Effect.all([funnel.summarize(), content.getTop()])` for parallel fetch.

### Helper Functions in Models

Pure domain logic belongs in `models.ts`, NOT in the orchestrator. These are functions that transform domain types without requiring services:

```typescript
// models.ts — pure domain helpers
export const isValidTransition = (from: FunnelStage, to: FunnelStage): boolean => { ... }
export const targetStageForEvent = (event: LedgerEvent): Option.Option<FunnelStage> => { ... }
export const sessionIdFromEvent = (event: LedgerEvent): Option.Option<SessionId> => { ... }
```

Every future orchestrator gets these for free. The orchestrator stays high-level.

### Options-Object Pattern for Queries

Prefer a single `query(opts)` method over method-per-filter:

```typescript
// BAD — method explosion, each new filter = new method
readonly queryByPerson: (id: PersonId) => Effect<ReadonlyArray<Event>>
readonly queryByPost: (id: PostId) => Effect<ReadonlyArray<Event>>
readonly queryBySince: (since: DateTimeUtc) => Effect<ReadonlyArray<Event>>

// GOOD — extensible, add fields without breaking callers
readonly query: (opts: {
  readonly personId?: PersonId
  readonly postId?: PostId
  readonly since?: DateTimeUtc
  readonly limit?: number
}) => Effect<ReadonlyArray<Event>>
```

---

## Velocity

**The sketch is disposable.** Speed matters in Phase 1. Find interface problems fast, don't polish. A sketch that takes 30 minutes and reveals a bad decomposition saves 3 hours of implementation down the wrong path.

If something feels wrong, delete the sketch and start over. The cost of deletion is low. The cost of forcing a bad interface through 4 more phases is enormous.

---

## Anti-Patterns

- `Schema.String.pipe(Schema.brand("X"))` with no constraints — the brand enforces nothing
- Designing services before the orchestrator — interfaces should EMERGE from composition
- Property tests deferred to Phase 2 — they belong here, co-designed with schemas
- `interface` or plain `class` for domain models — use `Schema.Class` for entities, `Schema.Struct` for DTOs
- `Data.TaggedError` instead of `Schema.TaggedError` — Schema version is serializable + yieldable
