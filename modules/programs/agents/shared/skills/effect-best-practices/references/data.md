# Collections & State Patterns

## Chunk (Immutable Sequences)

Prefer `Chunk` over `Array` for immutable collection operations.

```typescript
import * as Chunk from "effect/Chunk"

// Creation
const empty: Chunk.Chunk<string> = Chunk.empty()
const fromArray = Chunk.fromIterable([1, 2, 3])
const single = Chunk.make("a", "b", "c")

// Append (returns NEW Chunk)
const updated = Chunk.append(chunk, newItem)
const prepended = Chunk.prepend(chunk, newItem)
const concatenated = Chunk.appendAll(chunk1, chunk2)

// Access
const first = Chunk.unsafeGet(chunk, 0)  // Throws if out of bounds
const head = Chunk.head(chunk)           // Option<A>
const size = Chunk.size(chunk)
const isEmpty = Chunk.isEmpty(chunk)

// Transform
const mapped = Chunk.map(chunk, (x) => x * 2)
const filtered = Chunk.filter(chunk, predicate)
const taken = Chunk.take(chunk, 5)       // First 5 elements
const dropped = Chunk.drop(chunk, 3)     // Skip first 3

// Search
const found = Chunk.findFirst(chunk, (x) => x.type === "user")
// Returns Option<A>

// Convert
const array = Chunk.toReadonlyArray(chunk)
```

## Option (Nullable Values)

```typescript
import * as Option from "effect/Option"

// Creation
const some = Option.some(value)
const none = Option.none()
const fromNullable = Option.fromNullable(maybeNull)

// Safe unwrap
const value = Option.getOrElse(option, () => defaultValue)
const valueOrNull = Option.getOrNull(option)
const valueOrUndefined = Option.getOrUndefined(option)

// Pattern match
const result = Option.match(option, {
  onNone: () => "nothing",
  onSome: (v) => `got ${v}`
})

// Check and access
if (option._tag === "Some") {
  const value = option.value
}

// Transform
const mapped = Option.map(option, (x) => x * 2)
const flatMapped = Option.flatMap(option, (x) =>
  x > 0 ? Option.some(x) : Option.none()
)

// From Chunk.findFirst
const found = Chunk.findFirst(lines, isMessageLine)
if (found._tag === "Some") {
  const line = found.value
  // line is narrowed to the filtered type
}
```

## Ref (Mutable State)

Refs provide thread-safe mutable state within Effect.

```typescript
import * as Ref from "effect/Ref"

// Create
const counterRef = yield* Ref.make(0)
const stateRef = yield* Ref.make({ count: 0, items: [] as string[] })

// Read
const current = yield* Ref.get(stateRef)

// Update (pure function, returns void)
yield* Ref.update(stateRef, (state) => ({
  ...state,
  count: state.count + 1
}))

// Update and get new value
const newState = yield* Ref.updateAndGet(stateRef, (s) => ({
  ...s,
  count: s.count + 1
}))

// Set directly
yield* Ref.set(stateRef, newValue)

// Modify (update + return arbitrary value)
const oldCount = yield* Ref.modify(stateRef, (state) => [
  state.count,                              // Return value
  { ...state, count: state.count + 1 }      // New state
])
```

### Ref Pattern for Service State

```typescript
export const makeSessionStore = (config: Config) =>
  Effect.gen(function* () {
    const stateRef = yield* Ref.make<SessionState>({
      sessionId: config.sessionId,
      turnCount: 0,
      isComplete: false,
      lines: Chunk.empty()
    })

    return {
      getState: Ref.get(stateRef),

      getSessionState: Effect.gen(function* () {
        const state = yield* Ref.get(stateRef)
        return {
          sessionId: state.sessionId,
          turnCount: state.turnCount,
          isComplete: state.isComplete
        }
      }),

      incrementTurn: Ref.update(stateRef, (s) => ({
        ...s,
        turnCount: s.turnCount + 1
      })),

      appendLine: (line: Line) =>
        Ref.update(stateRef, (s) => ({
          ...s,
          lines: Chunk.append(s.lines, line)
        })),

      markComplete: Ref.update(stateRef, (s) => ({
        ...s,
        isComplete: true
      }))
    }
  })
```

## HashMap (Immutable Maps)

```typescript
import * as HashMap from "effect/HashMap"

const map = HashMap.empty<string, number>()
const withEntry = HashMap.set(map, "key", 42)
const value = HashMap.get(withEntry, "key")  // Option<number>
const removed = HashMap.remove(withEntry, "key")
const size = HashMap.size(map)
```

## HashSet (Immutable Sets)

```typescript
import * as HashSet from "effect/HashSet"

const set = HashSet.empty<string>()
const withItem = HashSet.add(set, "item")
const has = HashSet.has(withItem, "item")  // boolean
const removed = HashSet.remove(withItem, "item")
```

## Either (Explicit Success/Failure)

```typescript
import * as Either from "effect/Either"

// From Effect
const result = yield* effect.pipe(Effect.either)
// result: Either<E, A>

if (Either.isRight(result)) {
  const value = result.right
} else {
  const error = result.left
}

// Pattern match
Either.match(result, {
  onLeft: (error) => handleError(error),
  onRight: (value) => handleSuccess(value)
})
```
