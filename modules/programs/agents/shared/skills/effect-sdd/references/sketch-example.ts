/**
 * Service-Driven Development — Canonical Example (v2)
 *
 * Domain: Event registration (Luma-style)
 *
 * Demonstrates the full SDD Phase 1 output:
 *   - Schema models with REAL constraints (not bare strings)
 *   - Context.Tag service interfaces emerging from orchestrator
 *   - Orchestrator composing services
 *   - Property tests co-designed with schemas
 *
 * Phase 2 (Layer.mock stubs + orchestration tests) would be in a
 * separate .test.ts file using @effect/vitest.
 */

import { Context, Effect, Layer, Schema } from "effect"

// ============================================================================
// DOMAIN MODELS — Schema with constraints
// ============================================================================

// Branded IDs with real invariants (not bare strings)
const UserId = Schema.NonEmptyString.pipe(
  Schema.pattern(/^usr_[a-z0-9]{12}$/),
  Schema.brand("UserId")
)
type UserId = typeof UserId.Type

const EventId = Schema.UUID.pipe(Schema.brand("EventId"))
type EventId = typeof EventId.Type

const Email = Schema.NonEmptyString.pipe(
  Schema.pattern(/^[^@\s]+@[^@\s]+\.[^@\s]+$/),
  Schema.brand("Email")
)
type Email = typeof Email.Type

const TicketCode = Schema.NonEmptyString.pipe(
  Schema.pattern(/^[A-Z]{3}-[0-9]{3}$/),
  Schema.brand("TicketCode")
)
type TicketCode = typeof TicketCode.Type

// Entities — Schema.Class with constrained fields
class User extends Schema.Class<User>("User")({
  id: UserId,
  name: Schema.NonEmptyString.pipe(Schema.maxLength(100)),
  email: Email,
}) {}

class Ticket extends Schema.Class<Ticket>("Ticket")({
  id: Schema.NonEmptyString,
  eventId: EventId,
  userId: UserId,
  code: TicketCode,
}) {}

class Registration extends Schema.Class<Registration>("Registration")({
  user: User,
  ticket: Ticket,
  confirmationSent: Schema.Boolean,
}) {}

// Errors — Schema.TaggedError (yieldable — no Effect.fail needed)
class UserNotFound extends Schema.TaggedError<UserNotFound>()("UserNotFound", {
  userId: UserId,
}) {}

class TicketIssueError extends Schema.TaggedError<TicketIssueError>()(
  "TicketIssueError",
  { reason: Schema.NonEmptyString },
) {}

class EmailSendError extends Schema.TaggedError<EmailSendError>()(
  "EmailSendError",
  { to: Email, reason: Schema.NonEmptyString },
) {}

// ============================================================================
// LEAF SERVICES — Context.Tag = pure interface
// These EMERGED from writing the orchestrator below.
// ============================================================================

class Users extends Context.Tag("Users")<Users, {
  readonly findById: (id: UserId) => Effect.Effect<User, UserNotFound>
}>() {}

class Tickets extends Context.Tag("Tickets")<Tickets, {
  readonly issue: (eventId: EventId, userId: UserId) => Effect.Effect<Ticket, TicketIssueError>
}>() {}

class Emails extends Context.Tag("Emails")<Emails, {
  readonly send: (to: Email, subject: string, body: string) => Effect.Effect<void, EmailSendError>
}>() {}

// ============================================================================
// ORCHESTRATOR — real implementation composing leaf services
// Written FIRST. The Tags above were extracted from what this needs.
// ============================================================================

// Typechecks with zero implementations.
// Compiler infers:
//   Error:   UserNotFound | TicketIssueError | EmailSendError
//   Context: Users | Tickets | Emails

const registerForEvent = (eventId: EventId, userId: UserId) =>
  Effect.gen(function* () {
    const users = yield* Users
    const tickets = yield* Tickets
    const emails = yield* Emails

    const user = yield* users.findById(userId)
    const ticket = yield* tickets.issue(eventId, userId)
    yield* emails.send(user.email, "Registration Confirmed", `Ticket: ${ticket.code}`)

    return new Registration({ user, ticket, confirmationSent: true })
  })

// ============================================================================
// PHASE 2: Layer.mock stubs (would be in a .test.ts file)
// ============================================================================

const MockUsers = Layer.succeed(Users, {
  findById: (id) =>
    Effect.succeed(new User({
      id,
      name: "Test User",
      email: Email.make("test@example.com"),
    })),
})

const MockTickets = Layer.succeed(Tickets, {
  issue: (eventId, userId) =>
    Effect.succeed(new Ticket({
      id: "ticket-001",
      eventId,
      userId,
      code: TicketCode.make("ABC-123"),
    })),
})

const MockEmails = Layer.succeed(Emails, {
  send: (_to, _subject, _body) => Effect.void,
})

const TestLayer = Layer.mergeAll(MockUsers, MockTickets, MockEmails)

// ============================================================================
// PROPERTY TESTS (would be in a .test.ts file with @effect/vitest)
//
// These are PSEUDOCODE showing what the real tests look like.
// Actual tests use: import { it } from "@effect/vitest"
// ============================================================================

// --- Phase 1: Schema property tests (co-designed with models) ---
//
// it.prop("User roundtrip", [User], (user) =>
//   Effect.gen(function*() {
//     const encoded = Schema.encodeSync(User)(user)
//     const decoded = Schema.decodeSync(User)(encoded)
//     expect(decoded).toEqual(user)
//   })
// )
//
// it.prop("UserId always matches pattern", [UserId], (id) =>
//   Effect.sync(() => {
//     expect(id).toMatch(/^usr_[a-z0-9]{12}$/)
//   })
// )
//
// it.prop("Email is never empty", [Email], (email) =>
//   Effect.sync(() => {
//     expect(email.length).toBeGreaterThan(0)
//     expect(email).toContain("@")
//   })
// )

// --- Phase 2: Orchestration property tests ---
//
// it.effect.prop(
//   "registration always includes the requested user",
//   { userId: UserId, eventId: EventId },
//   ({ userId, eventId }) =>
//     Effect.gen(function*() {
//       const result = yield* registerForEvent(eventId, userId)
//       expect(result.user.id).toBe(userId)
//       expect(result.ticket.eventId).toBe(eventId)
//     }).pipe(Effect.provide(TestLayer))
// )

// --- Runnable demo ---
const main = registerForEvent(
  EventId.make("550e8400-e29b-41d4-a716-446655440000"),
  UserId.make("usr_a1b2c3d4e5f6"),
).pipe(Effect.provide(TestLayer))

// Effect.runPromise(main).then(console.log)
