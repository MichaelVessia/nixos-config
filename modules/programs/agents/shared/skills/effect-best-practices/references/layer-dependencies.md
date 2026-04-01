# Layer & Service Dependency Patterns

## The One True Pattern: Capture at Construction

Effect services access dependencies by yielding them in Effect.gen at layer construction time,
then closing over them in method implementations.

## Idiomatic Pattern

```typescript
const make = Effect.gen(function*() {
  // Yield deps once at construction
  const config = yield* Config
  const storage = yield* Storage
  const clock = yield* Effect.clock

  // Return service whose methods close over deps
  return {
    doThing: (x) => storage.get(x),  // uses storage via closure
    getTime: () => clock.currentTimeMillis,  // uses clock via closure
  }
})

export const Live = Layer.effect(MyService, make)
// or Layer.scoped if resource cleanup needed
```

## Why NOT Factory Functions

```typescript
// AVOID: Passing deps as function params
function makeService(storage: StorageService): MyService { ... }

export const Live = Layer.effect(
  MyService,
  Effect.gen(function* () {
    const storage = yield* Storage
    return makeService(storage)  // <-- unusual, avoid
  })
)

// PREFER: Yield directly, close over
const make = Effect.gen(function*() {
  const storage = yield* Storage
  return { ... }  // methods close over storage
})
```

**Why this matters:**
- Factory functions add unnecessary indirection
- Passing deps as params obscures the Effect dependency graph
- The idiomatic pattern keeps deps visible in the Effect.gen body
- Easier to add/remove deps without changing function signatures

## Method Return Types

Service methods return `Effect<A, E, never>` - deps already satisfied by closure.

```typescript
interface MyService {
  // never in R position - deps not required per-call
  readonly doThing: (x: string) => Effect.Effect<Result, MyError>
}
```

**Code smell:** If you see `Effect<A, E, SomeDep>` in a service method return type,
deps are being required per-call instead of captured at construction.

## When to Use Each Layer Constructor

| Constructor | Use When |
|-------------|----------|
| `Layer.succeed` | Pure value, no deps, no effects |
| `Layer.effect` | Has deps OR construction is effectful |
| `Layer.scoped` | Has deps AND needs resource cleanup (acquireRelease) |

### Layer.succeed

```typescript
// Static config or pure implementations
export const ConfigLive = Layer.succeed(Config, {
  timeout: 5000,
  retries: 3,
})
```

### Layer.effect

```typescript
// Stateful or has dependencies
const make = Effect.gen(function*() {
  const dep = yield* SomeDep
  const state = yield* Ref.make(initialState)
  return { ... }
})

export const ServiceLive = Layer.effect(Service, make)
```

### Layer.scoped

```typescript
// Needs cleanup (connections, file handles, background fibers)
const make = Effect.gen(function*() {
  const connection = yield* Effect.acquireRelease(
    openConnection(),
    (conn) => closeConnection(conn)
  )

  // Or background fiber that needs cleanup
  yield* Effect.forkScoped(backgroundLoop)

  return { ... }
})

export const ServiceLive = Layer.scoped(Service, make)
```

## Real Examples from Effect Source

### @effect/cluster/Sharding.ts

```typescript
const make = Effect.gen(function*() {
  const config = yield* ShardingConfig
  const storage = yield* MessageStorage
  const runners = yield* Runners
  const scope = yield* Effect.scope

  // Internal state
  const state = yield* Ref.make(initialState)

  // All methods close over these deps
  return Sharding.of({
    register: (entity) => /* uses storage, runners */,
    send: (message) => /* uses config, runners, state */,
    getShardId: (entityId) => /* uses config */,
  })
})

export const layer = Layer.scoped(Sharding, make)
```

### @effect/cluster/Runners.ts

```typescript
export const makeRpc = Effect.gen(function*() {
  const makeClientProtocol = yield* RpcClientProtocol
  const snowflakeGen = yield* Snowflake.Generator

  // Resource pool - created once, used by all methods
  const clients = yield* RcMap.make({
    lookup: (address) => makeClientProtocol(address),
    idleTimeToLive: "3 minutes"
  })

  return {
    ping: (address) => RcMap.get(clients, address).pipe(
      Effect.flatMap((client) => client.Ping())
    ),
    send: ({ address, message }) => RcMap.get(clients, address).pipe(
      Effect.flatMap((client) => client.Send(message))
    ),
  }
})
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Factory function with service params | Obscures dependency graph | Yield deps in Effect.gen |
| `Effect<A, E, Dep>` in method signature | Deps required per-call | Capture at construction |
| `Layer.succeed` with stateful service | State shared across tests | Use `Layer.effect` for fresh state |
| Yielding deps inside methods | Repeated resolution overhead | Capture once in make |

## Testing Implications

The closure pattern means each layer instantiation gets fresh state:

```typescript
// Each test gets isolated state
it.effect("test 1", () =>
  Effect.gen(function* () {
    const svc = yield* MyService
    // svc has fresh state
  }).pipe(Effect.provide(MyServiceLive))
)

it.effect("test 2", () =>
  Effect.gen(function* () {
    const svc = yield* MyService
    // svc has fresh state, not polluted by test 1
  }).pipe(Effect.provide(MyServiceLive))
)
```
