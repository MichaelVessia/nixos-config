# Error Handling Patterns

## Research Resources

```bash
# Schema.TaggedError patterns from Effect source
# git clone https://github.com/Effect-TS/effect <effect-repo>
rg "Schema\.TaggedError" <effect-repo>/packages/cluster/src
rg "Schema\.TaggedError" <effect-repo>/packages/workflow/src

# Data.TaggedError (older pattern)
rg "Data\.TaggedError" <effect-repo>/packages/effect/src
```

---

## Schema.TaggedError (Canonical for Domain Errors)

**This is the idiomatic pattern.** All Effect official packages use `Schema.TaggedError` for domain errors.

### From @effect/cluster - ClusterError.ts

```typescript
import * as Cause from "effect/Cause"
import * as Effect from "effect/Effect"
import { hasProperty, isTagged } from "effect/Predicate"
import * as Schema from "effect/Schema"

// TypeId symbol for error family branding
export const TypeId: unique symbol = Symbol.for("@effect/cluster/ClusterError")
export type TypeId = typeof TypeId

// Error with address context
export class EntityNotAssignedToRunner extends Schema.TaggedError<EntityNotAssignedToRunner>()(
  "EntityNotAssignedToRunner",
  { address: EntityAddress }
) {
  readonly [TypeId] = TypeId

  // Static type guard
  static is(u: unknown): u is EntityNotAssignedToRunner {
    return hasProperty(u, TypeId) && isTagged(u, "EntityNotAssignedToRunner")
  }
}

// Error with cause (wraps underlying error)
export class MalformedMessage extends Schema.TaggedError<MalformedMessage>()(
  "MalformedMessage",
  { cause: Schema.Defect }
) {
  readonly [TypeId] = TypeId

  static is(u: unknown): u is MalformedMessage {
    return hasProperty(u, TypeId) && isTagged(u, "MalformedMessage")
  }

  // Static error remapping helper
  static refail: <A, E, R>(effect: Effect.Effect<A, E, R>) => Effect.Effect<
    A,
    MalformedMessage,
    R
  > = Effect.mapError((cause) => new MalformedMessage({ cause }))
}

// Error with squashed cause (catches all)
export class PersistenceError extends Schema.TaggedError<PersistenceError>()(
  "PersistenceError",
  { cause: Schema.Defect }
) {
  readonly [TypeId] = TypeId

  // Catches any error and wraps in PersistenceError
  static refail<A, E, R>(effect: Effect.Effect<A, E, R>): Effect.Effect<A, PersistenceError, R> {
    return Effect.catchAllCause(effect, (cause) =>
      Effect.fail(new PersistenceError({ cause: Cause.squash(cause) }))
    )
  }
}

// Simple error with address
export class RunnerNotRegistered extends Schema.TaggedError<RunnerNotRegistered>()(
  "RunnerNotRegistered",
  { address: RunnerAddress }
) {
  readonly [TypeId] = TypeId
}

// Error with multiple fields
export class AlreadyProcessingMessage extends Schema.TaggedError<AlreadyProcessingMessage>()(
  "AlreadyProcessingMessage",
  {
    envelopeId: SnowflakeFromString,
    address: EntityAddress
  }
) {
  readonly [TypeId] = TypeId

  static is(u: unknown): u is AlreadyProcessingMessage {
    return hasProperty(u, TypeId) && isTagged(u, "AlreadyProcessingMessage")
  }
}
```

### Key Elements of Schema.TaggedError Pattern

1. **TypeId symbol** - brands error family for type-safe discrimination
2. **Static `is()` method** - type guard for runtime checks
3. **Static `refail()` method** - helper for error mapping
4. **Schema fields** - structured, validated, serializable

### Complete Error Module Template

```typescript
import * as Cause from "effect/Cause"
import * as Effect from "effect/Effect"
import { hasProperty, isTagged } from "effect/Predicate"
import * as Schema from "effect/Schema"

// TypeId for error family
export const TypeId: unique symbol = Symbol.for("@myapp/MyError")
export type TypeId = typeof TypeId

// Domain-specific error
export class NotFoundError extends Schema.TaggedError<NotFoundError>()(
  "NotFoundError",
  {
    resource: Schema.String,
    id: Schema.String
  }
) {
  readonly [TypeId] = TypeId

  static is(u: unknown): u is NotFoundError {
    return hasProperty(u, TypeId) && isTagged(u, "NotFoundError")
  }
}

// Error wrapping underlying cause
export class IOError extends Schema.TaggedError<IOError>()(
  "IOError",
  {
    operation: Schema.Literal("read", "write", "delete"),
    path: Schema.String,
    cause: Schema.Defect
  }
) {
  readonly [TypeId] = TypeId

  static is(u: unknown): u is IOError {
    return hasProperty(u, TypeId) && isTagged(u, "IOError")
  }

  // Map any error to IOError
  static refail<A, E, R>(
    operation: "read" | "write" | "delete",
    path: string
  ) {
    return (effect: Effect.Effect<A, E, R>): Effect.Effect<A, IOError, R> =>
      Effect.catchAllCause(effect, (cause) =>
        Effect.fail(new IOError({ operation, path, cause: Cause.squash(cause) }))
      )
  }
}

// Validation error with structured context
export class ValidationError extends Schema.TaggedError<ValidationError>()(
  "ValidationError",
  {
    field: Schema.String,
    expected: Schema.String,
    received: Schema.Unknown
  }
) {
  readonly [TypeId] = TypeId

  static is(u: unknown): u is ValidationError {
    return hasProperty(u, TypeId) && isTagged(u, "ValidationError")
  }
}
```

---

## Why Schema.TaggedError over Data.TaggedError

| Feature | Schema.TaggedError | Data.TaggedError |
|---------|-------------------|------------------|
| JSON serialization | Built-in | Manual |
| Schema validation | Built-in | Manual |
| TypeId branding | Add yourself | No pattern |
| Static is() guard | Add yourself | No pattern |
| Static refail() | Add yourself | No pattern |
| Effect error channel | Full support | Full support |

**Rule:** Always use `Schema.TaggedError` for domain errors. `Data.TaggedError` is legacy.

---

## Error Mapping Patterns

### mapError - Transform error type

```typescript
const result = yield* fs.readFileString(path).pipe(
  Effect.mapError((cause) =>
    new IOError({ operation: "read", path, cause })
  )
)
```

### catchTag - Handle specific error

```typescript
const result = yield* effect.pipe(
  Effect.catchTag("NotFoundError", (error) =>
    error.resource === "user"
      ? Effect.succeed(defaultUser)
      : Effect.fail(error)  // re-throw
  )
)
```

### catchAll - Handle any error

```typescript
const result = yield* effect.pipe(
  Effect.catchAll((error) => {
    console.error("Failed:", error)
    return Effect.succeed(fallback)
  })
)
```

### catchAllCause - Handle full cause (including defects)

```typescript
// From @effect/cluster PersistenceError.refail
const result = yield* effect.pipe(
  Effect.catchAllCause((cause) =>
    Effect.fail(new PersistenceError({ cause: Cause.squash(cause) }))
  )
)
```

### Effect.either - Convert to Either for inspection

```typescript
const result = yield* effect.pipe(Effect.either)
if (Either.isLeft(result)) {
  console.log("Error:", result.left._tag)
} else {
  console.log("Success:", result.right)
}
```

### Effect.exit - Full exit inspection

```typescript
const exit = yield* effect.pipe(Effect.exit)
if (Exit.isFailure(exit)) {
  const cause = exit.cause
  // Can inspect cause for errors, defects, interruptions
}
```

### Effect.flip - Swap success/error (for testing)

```typescript
it.effect("should fail on invalid input", () =>
  Effect.gen(function* () {
    const service = yield* MyService
    const error = yield* service.doThing(badInput).pipe(Effect.flip)
    expect(error._tag).toBe("ValidationError")
  }).pipe(Effect.provide(TestLive))
)
```

---

## Error Union Types

### Service methods declare specific errors

```typescript
export class MyService extends Context.Tag("app/MyService")<MyService, {
  readonly load: (id: string) => Effect.Effect<Data, NotFoundError | IOError>
  readonly save: (data: Data) => Effect.Effect<void, ValidationError | IOError>
}>() {}
```

### Combined operations have union error type

```typescript
const loadAndSave = (id: string, transform: (d: Data) => Data) =>
  Effect.gen(function* () {
    const data = yield* service.load(id)       // NotFoundError | IOError
    const transformed = transform(data)
    yield* service.save(transformed)            // ValidationError | IOError
  })
// Type: Effect<void, NotFoundError | ValidationError | IOError>
```

---

## Effect.try for Sync Operations

```typescript
// With custom error mapping
const parsed = yield* Effect.try({
  try: () => JSON.parse(content),
  catch: (error) => new ParseError({
    reason: error instanceof Error ? error.message : String(error),
    input: content.slice(0, 100)
  })
})

// Simple form (wraps in generic UnknownException)
const result = yield* Effect.try(() => riskyOperation())
```

---

## Defect Handling

### Schema.Defect for wrapping unknown errors

```typescript
// Defect field captures any thrown value
export class MyError extends Schema.TaggedError<MyError>()(
  "MyError",
  { cause: Schema.Defect }
) {}

// Usage
Effect.catchAllCause(effect, (cause) =>
  Effect.fail(new MyError({ cause: Cause.squash(cause) }))
)
```

### Cause.squash - Flatten cause to single error

```typescript
// Converts complex Cause to single Throwable
const squashed = Cause.squash(cause)
// Type: unknown (the original thrown value)
```

---

## Common Patterns from Effect Source

### Error with refail helper (from ClusterError.ts)

```typescript
export class PersistenceError extends Schema.TaggedError<PersistenceError>()(
  "PersistenceError",
  { cause: Schema.Defect }
) {
  static refail<A, E, R>(effect: Effect.Effect<A, E, R>): Effect.Effect<A, PersistenceError, R> {
    return Effect.catchAllCause(effect, (cause) =>
      Effect.fail(new PersistenceError({ cause: Cause.squash(cause) }))
    )
  }
}

// Usage
const safePersist = PersistenceError.refail(rawDbCall)
```

### Error with context fields

```typescript
export class EntityNotAssignedToRunner extends Schema.TaggedError<EntityNotAssignedToRunner>()(
  "EntityNotAssignedToRunner",
  { address: EntityAddress }  // Typed context
) {}

// Usage
Effect.fail(new EntityNotAssignedToRunner({ address: myAddress }))
```

### Discriminated union of errors

```typescript
// All cluster errors share TypeId
export type ClusterError =
  | EntityNotAssignedToRunner
  | MalformedMessage
  | PersistenceError
  | RunnerNotRegistered
  | RunnerUnavailable
  | MailboxFull
  | AlreadyProcessingMessage

// Type guard for entire error family
const isClusterError = (u: unknown): u is ClusterError =>
  hasProperty(u, TypeId)
```

---

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| `Data.TaggedError` | Use `Schema.TaggedError` |
| String error messages | Use structured fields |
| `throw new Error()` in Effect code | Use `Effect.fail()` |
| `try/catch` in Effect.gen | Use `Effect.try` or `catchTag` |
| Catching without re-typing | Use `mapError` to convert types |
| No TypeId on errors | Add TypeId symbol for branding |
| No static `is()` method | Add for runtime type checks |
