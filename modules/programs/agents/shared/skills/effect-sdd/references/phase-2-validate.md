# Phase 2: Validate

## Gate (must pass before Phase 3)

- [ ] All orchestration tests pass in @effect/vitest
- [ ] All Phase 1 property tests still pass
- [ ] API review checklist completed (Phase 1.5)
- [ ] `npx effect-language-service quickfixes --project tsconfig.json` — zero diagnostics
- [ ] Layer.mock stubs exercise only the methods the orchestrator calls

---

## API Review (Phase 1.5)

**Before any test code.** A fresh reviewer examines the sketch.

### Review Checklist

1. **One sentence per service.** If you can't summarize what a service does in one sentence, split it.
2. **Gun to the head.** What's the absolute minimum set of services? If a service only has 1-2 trivial methods, maybe it's inline orchestrator logic, not a service.
3. **Deletion pass.** For each service method: who asked for this? The orchestrator? Or "best practice"? Flag anything that exists "in case we need it later" — delete it. **If you haven't deleted at least 1 service or 3 methods during review, you weren't aggressive enough.** You should be adding things back ~10% of the time — if you never are, you're not deleting enough.
4. **Error channel audit.** Are errors in the right service? Does the orchestrator's inferred error type make sense? Are there errors that should be in the error channel but aren't?
5. **Reader is never surprised.** Read each Context.Tag. Does every method flow obviously from the domain? If a method name or signature is surprising, the API is wrong.
6. **Anticipate objections.** What would a senior engineer push back on? Address it now.
7. **Only mock IO.** Which services do actual I/O (filesystem, network, database)? Those get Layer.mock. Which are pure computation? Those should be tested with real implementations in Phase 3.

### Who Reviews

In order of preference:
1. **Sub-agent** — fresh context, no sunk cost bias (haiku is fine for API review)
2. **Orchestrator self-review** — re-read the sketch after a pause
3. **Oracle/Codex** — external model review (if available, fast enough)

---

## Step 1: Layer.mock Stubs

Use `Layer.mock` for partial stubs. Unmocked methods throw `UnimplementedError`.

```typescript
import { Layer } from "effect"

// Only stub what the orchestrator calls
const MockUsers = Layer.mock(Users, {
  findById: (id) =>
    Effect.succeed(new User({ id, name: "Test User", email: Email.make("test@example.com") }))
  // discoverAll NOT stubbed → throws UnimplementedError if called
})

const MockTickets = Layer.mock(Tickets, {
  issue: (eventId, userId) =>
    Effect.succeed(new Ticket({ id: "tk-1", eventId, userId, code: "ABC-123" }))
})

const MockEmails = Layer.mock(Emails, {
  send: (_to, _subject, _body) => Effect.void
})

const TestLayer = Layer.mergeAll(MockUsers, MockTickets, MockEmails)
```

For **error path testing**, create alternative mocks:

```typescript
const MockUsersNotFound = Layer.mock(Users, {
  findById: (id) => yield* new UserNotFound({ userId: id })
})

const ErrorLayer = Layer.mergeAll(MockUsersNotFound, MockTickets, MockEmails)
```

For **stateful testing** (verify side effects), use `Layer.effect` + `Ref`:

```typescript
const StatefulEmails = Layer.effect(Emails,
  Effect.gen(function*() {
    const sent = yield* Ref.make<Array<{ to: string; subject: string }>>([])
    return {
      send: (to, subject, _body) =>
        Ref.update(sent, (arr) => [...arr, { to, subject }]),
      _sent: sent,  // expose for assertions
    }
  })
)
```

---

## Step 2: Orchestration Tests (@effect/vitest)

**These are REAL vitest tests, not bun scripts.**

```typescript
// test/orchestration.test.ts
import { describe, it } from "@effect/vitest"

describe("registerForEvent orchestration", () => {

  it.effect("happy path returns Registration", () =>
    Effect.gen(function*() {
      const result = yield* registerForEvent(
        EventId.make("evt-1"),
        UserId.make("usr-1")
      )
      expect(result.confirmationSent).toBe(true)
      expect(result.ticket.code).toBe("ABC-123")
    }).pipe(Effect.provide(TestLayer))
  )

  it.effect("propagates UserNotFound", () =>
    Effect.gen(function*() {
      const result = yield* registerForEvent(
        EventId.make("evt-1"),
        UserId.make("usr-missing")
      ).pipe(Effect.either)

      expect(result._tag).toBe("Left")
      if (result._tag === "Left") {
        expect(result.left._tag).toBe("UserNotFound")
      }
    }).pipe(Effect.provide(ErrorLayer))
  )

  it.effect("dry run does not send email", () =>
    Effect.gen(function*() {
      const result = yield* registerForEvent(
        EventId.make("evt-1"),
        UserId.make("usr-1")
      )
      // verify via stateful mock
      const emails = yield* Ref.get(sentEmails)
      expect(emails).toHaveLength(1)
      expect(emails[0]!.to).toBe("test@example.com")
    }).pipe(Effect.provide(StatefulLayer))
  )
})
```

### What to Test

| Scenario | Required |
|----------|----------|
| Happy path | Always |
| Each error type propagates correctly | Always |
| Conditional logic in orchestrator | Each branch |
| Side effects (if stateful mock) | Verify calls made |

---

## Step 3: Additional Property Tests

Phase 1 property tests tested schemas in isolation. Phase 2 adds orchestration-level properties:

```typescript
describe("orchestration properties", () => {

  it.effect.prop(
    "registration always includes the requested user",
    { userId: UserId, eventId: EventId },
    ({ userId, eventId }) =>
      Effect.gen(function*() {
        const result = yield* registerForEvent(eventId, userId)
        expect(result.user.id).toBe(userId)
        expect(result.ticket.eventId).toBe(eventId)
      }).pipe(Effect.provide(TestLayer))
  )

  // Crash test: random valid inputs never throw
  it.effect.prop(
    "orchestrator never throws on valid input",
    { userId: UserId, eventId: EventId },
    ({ userId, eventId }) =>
      Effect.gen(function*() {
        const result = yield* registerForEvent(eventId, userId).pipe(Effect.either)
        // Either success or tagged error — never a throw
        expect(result).toBeDefined()
      }).pipe(Effect.provide(TestLayer))
  )
})
```

---

## Anti-Patterns

- Bun scripts with `console.log("PASS"/"FAIL")` — use @effect/vitest
- `Layer.succeed` when `Layer.mock` would surface untested paths
- Testing implementation details instead of behavior
- Skipping error path tests
- Manual assertions instead of `expect()`
