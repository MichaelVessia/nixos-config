# Service & Layer Patterns

## Research Resources

**Effect Docs MCP** - Use for conceptual understanding:
```typescript
mcp__effect-docs__effect_docs_search({ query: "Context.Tag" })
mcp__effect-docs__get_effect_doc({ documentId: <id> })
```

**Effect Source** — Use for real implementation patterns:
```bash
# Clone Effect source: git clone https://github.com/Effect-TS/effect <effect-repo>

# Library service interfaces (Context.Tag)
rg "class .* extends Context\.Tag" <effect-repo>/packages/workflow/src
rg "class .* extends Context\.Tag" <effect-repo>/packages/cluster/src

# Concrete implementations (Effect.Service)
rg "Effect\.Service" <effect-repo>/packages/cluster/src

# Platform patterns
rg "Layer.provide|Layer.provideMerge" <effect-repo>/packages/platform/src
```

---

## Two Patterns: When to Use Each

| Pattern | Use When | Examples |
|---------|----------|----------|
| **Context.Tag** | Library interfaces, multiple implementations, no "default" | WorkflowEngine, Sharding, MessageStorage |
| **Effect.Service** | Concrete implementations, tests, app code with single impl | MemoryDriver, TestEntityState, app services |

**Rule of thumb:**
- Building a library? Use `Context.Tag` for service interfaces
- Building an app or test? `Effect.Service` is convenient
- Need multiple layer variants (Live, Test, Mock)? Use `Context.Tag`

---

## Context.Tag (Library/Interface Pattern)

**This is the canonical pattern for library service interfaces.** All Effect official packages use this for their main services.

### From @effect/workflow

```typescript
// WorkflowEngine.ts - interface with no default implementation
export class WorkflowEngine extends Context.Tag("@effect/workflow/WorkflowEngine")<
  WorkflowEngine,
  {
    readonly register: <...>(...) => Effect.Effect<void, never, ...>
    readonly execute: <...>(...) => Effect.Effect<Success, Error, ...>
    readonly poll: <...>(...) => Effect.Effect<Result | undefined, never, ...>
    readonly interrupt: (executionId: string) => Effect.Effect<void>
    readonly resume: (executionId: string) => Effect.Effect<void>
  }
>() {}

// WorkflowInstance - another service interface
export class WorkflowInstance extends Context.Tag("@effect/workflow/WorkflowEngine/WorkflowInstance")<
  WorkflowInstance,
  {
    readonly executionId: string
    readonly id: string
    // ... more methods
  }
>() {}
```

### From @effect/cluster

```typescript
// Sharding.ts - core service interface
export class Sharding extends Context.Tag("@effect/cluster/Sharding")<Sharding, {
  readonly register: <...>(...) => Effect.Effect<void, never, Scope>
  readonly unregister: <...>(...) => Effect.Effect<void>
  readonly getShardId: (...) => Effect.Effect<ShardId>
  readonly messenger: <...>(...) => Effect.Effect<Messenger>
  // ... more methods
}>() {}

// MessageStorage.ts - storage interface (multiple impls: Memory, Sql)
export class MessageStorage extends Context.Tag("@effect/cluster/MessageStorage")<MessageStorage, {
  readonly saveRequest: (...) => Effect.Effect<void, PersistenceError>
  readonly getUnprocessed: (...) => Effect.Effect<Array<...>, PersistenceError>
  readonly ack: (...) => Effect.Effect<void, PersistenceError>
  // ... more methods
}>() {}

// ShardingConfig.ts - config service
export class ShardingConfig extends Context.Tag("@effect/cluster/ShardingConfig")<ShardingConfig, {
  readonly shardsPerGroup: number
  readonly entityMailboxCapacity: number
  readonly entityTerminationTimeout: number
  // ... more config
}>() {
  // Static layer factory for config
  static layer(config: Omit<...>): Layer.Layer<ShardingConfig> {
    return Layer.succeed(ShardingConfig, { ...defaults, ...config })
  }
}

// RunnerStorage.ts - another storage interface
export class RunnerStorage extends Context.Tag("@effect/cluster/RunnerStorage")<RunnerStorage, {
  readonly register: (...) => Effect.Effect<void, PersistenceError>
  readonly unregister: (...) => Effect.Effect<void, PersistenceError>
  readonly getRunners: Effect.Effect<Array<Runner>, PersistenceError>
}>() {}
```

### Creating Layers for Context.Tag Services

```typescript
// Option 1: Layer.effect - effectful construction
export const ShardingLive: Layer.Layer<Sharding, never, Deps> = Layer.effect(
  Sharding,
  Effect.gen(function* () {
    const config = yield* ShardingConfig
    const storage = yield* MessageStorage
    // ... setup
    return {
      register: (...) => ...,
      getShardId: (...) => ...,
      // ... implementation
    }
  })
)

// Option 2: Layer.scoped - lifecycle management
export const ShardingLive = Layer.scoped(
  Sharding,
  Effect.gen(function* () {
    const scope = yield* Scope.Scope
    // acquire resources
    return { ... }
  })
)

// Option 3: Layer.succeed - static config
export const ShardingConfigLive = ShardingConfig.layer({
  shardsPerGroup: 300,
  entityMailboxCapacity: 10
})

// Option 4: Layer.sync - synchronous construction
export const SimpleLive = Layer.sync(MyService, () => ({
  doThing: () => Effect.succeed("result")
}))
```

---

## Effect.Service (Concrete Implementation Pattern)

**Use for concrete implementations, tests, and application services with a single default.**

### From @effect/cluster - MemoryDriver (concrete impl of MessageStorage)

```typescript
// MessageStorage.ts - concrete Memory implementation
export class MemoryDriver extends Effect.Service<MemoryDriver>()(
  "@effect/cluster/MessageStorage/MemoryDriver",
  {
    dependencies: [Snowflake.layerGenerator],
    effect: Effect.gen(function* () {
      const clock = yield* Effect.clock
      const requests = new Map<string, MemoryEntry>()
      const requestsByPrimaryKey = new Map<string, MemoryEntry>()
      const unprocessed = new Set<Envelope.Envelope.Encoded>()

      return {
        saveRequest: (envelope) => Effect.sync(() => {
          requests.set(envelope.requestId, { ... })
          unprocessed.add(envelope)
        }),
        getUnprocessed: () => Effect.sync(() => [...unprocessed]),
        ack: (requestId) => Effect.sync(() => unprocessed.delete(...))
      }
    })
  }
) {}

// Usage: MemoryDriver.Default is the Layer
```

### From @effect/cluster/test - TestEntityState (test service)

```typescript
export class TestEntityState extends Effect.Service<TestEntityState>()(
  "TestEntityState",
  {
    effect: Effect.gen(function* () {
      const messages = yield* Mailbox.make<void>()
      const streamMessages = yield* Mailbox.make<void>()
      const envelopes = yield* Mailbox.make<...>()
      const defectTrigger = MutableRef.make(false)

      return {
        messages,
        streamMessages,
        envelopes,
        defectTrigger
      } as const
    })
  }
) {}

// Usage in tests
const TestEntityLayer = TestEntityNoState.pipe(
  Layer.provideMerge(TestEntityState.Default)
)
```

### Effect.Service Options

```typescript
// effect - basic effectful construction
Effect.Service<T>()("id", {
  effect: Effect.gen(function* () { return { ... } })
})

// scoped - for resources needing cleanup
Effect.Service<T>()("id", {
  scoped: Effect.gen(function* () {
    const resource = yield* Effect.acquireRelease(...)
    return { ... }
  })
})

// sync - synchronous construction
Effect.Service<T>()("id", {
  sync: () => ({ ... })
})

// succeed - static value
Effect.Service<T>()("id", {
  succeed: { doThing: () => Effect.succeed("result") }
})

// With dependencies - auto-composed into .Default layer
Effect.Service<T>()("id", {
  effect: Effect.gen(function* () { ... }),
  dependencies: [Dep1.Default, Dep2.Default]
})

// With accessors - generates static accessor methods
Effect.Service<T>()("id", {
  accessors: true,
  effect: Effect.gen(function* () {
    return { info: (msg: string) => Effect.log(msg) }
  })
})
// Now you can call: Logger.info("hello") directly
```

---

## Platform Services (Reference)

From @effect/platform - canonical service definitions:

```typescript
// FileSystem service interface
export class FileSystem extends Context.Tag("@effect/platform/FileSystem")<
  FileSystem,
  FileSystem.FileSystem
>() {}

// Path service interface
export class Path extends Context.Tag("@effect/platform/Path")<
  Path,
  Path.Path
>() {}

// NodeContext bundles platform services
export const layer: Layer.Layer<NodeContext> = pipe(
  Layer.mergeAll(
    NodePath.layer,
    NodeCommandExecutor.layer,
    NodeTerminal.layer,
    NodeWorker.layerManager
  ),
  Layer.provideMerge(NodeFileSystem.layer)
)
```

---

## Layer Composition

### Layer.mergeAll vs Layer.provideMerge vs Layer.provide

| Method | Deps Satisfied | Included in Output | Use Case |
|--------|---------------|-------------------|----------|
| `Layer.mergeAll` | No | Yes | Combine independent layers |
| `Layer.provide` | Yes | No | Internal layer building |
| `Layer.provideMerge` | Yes | Yes | Test setup, expose deps |

```typescript
// Layer.mergeAll - just unions, doesn't resolve deps
const Wrong = Layer.mergeAll(
  NodeFileSystem.layer,  // Layer<FileSystem>
  MyService.Live         // Layer<MyService, never, FileSystem>
)
// Result: Layer<FileSystem | MyService, never, FileSystem>
// PROBLEM: FileSystem still required!

// Layer.provideMerge - satisfies deps AND keeps in output
const Correct = MyService.Live.pipe(
  Layer.provideMerge(NodeFileSystem.layer)
)
// Result: Layer<MyService | FileSystem, never, never>
// All services available, deps satisfied

// Layer.provide - satisfies deps but hides provider
const Internal = MyService.Live.pipe(
  Layer.provide(NodeFileSystem.layer)
)
// Result: Layer<MyService, never, never>
// Only MyService exposed
```

### Test Layer Setup

```typescript
// From @effect/cluster tests
const TestShardingConfig = ShardingConfig.layer({
  shardsPerGroup: 300,
  entityMailboxCapacity: 10,
  entityTerminationTimeout: 0
})

// Proper layer composition for tests
const TestLayer = TestEntityNoState.pipe(
  Layer.provideMerge(TestEntityState.Default)
)

// Usage in tests - MUST provide at boundary
it.scoped("round trip", () =>
  Effect.gen(function* () {
    const makeClient = yield* Entity.makeTestClient(TestEntity, TestEntityLayer)
    const client = yield* makeClient("123")
    const user = yield* client.GetUser({ id: 1 })
    assert.deepEqual(user, new User({ id: 1, name: "User 1" }))
  }).pipe(Effect.provide(TestShardingConfig))
)
```

### Chaining Dependencies

```typescript
// When ServiceC depends on B depends on A
const LiveStack = ServiceC.Live.pipe(
  Layer.provideMerge(ServiceB.Live),
  Layer.provideMerge(ServiceA.Live),
  Layer.provideMerge(PlatformLive)
)
```

---

## Common Patterns from Effect Source

### Config Service Pattern

```typescript
export class MyConfig extends Context.Tag("app/MyConfig")<MyConfig, {
  readonly timeout: number
  readonly retries: number
}>() {
  // Static factory for layer
  static layer(config: Partial<...>): Layer.Layer<MyConfig> {
    return Layer.succeed(MyConfig, { ...defaults, ...config })
  }
}

// Usage
const MyConfigLive = MyConfig.layer({ timeout: 5000 })
```

### Service with Static Live Layer

```typescript
export class MyService extends Context.Tag("app/MyService")<MyService, {
  readonly doThing: (x: string) => Effect.Effect<Result, MyError>
}>() {
  // Static Live layer - deps declared in type
  static readonly Live: Layer.Layer<MyService, never, Dep1 | Dep2> =
    Layer.effect(
      MyService,
      Effect.gen(function* () {
        const dep1 = yield* Dep1
        const dep2 = yield* Dep2
        return {
          doThing: (x) => Effect.succeed(`processed: ${x}`)
        }
      })
    )
}
```

### Internal Service Pattern

```typescript
// For internal-only services (not part of public API)
/** @internal */
export class EntityReaper extends Effect.Service<EntityReaper>()(
  "@effect/cluster/EntityReaper",
  {
    scoped: Effect.gen(function* () {
      // ... internal impl
      return { ... }
    })
  }
) {}
```

---

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| `Data.TaggedError` for domain errors | Use `Schema.TaggedError` |
| `Layer.mergeAll` with dependent layers | Use `Layer.provideMerge` |
| Missing `.pipe(Effect.provide(...))` in tests | Always provide at test boundary |
| Factory function returning plain object | Return from `Effect.gen` inside Layer.effect |
| Mixing Effect.Service for library interfaces | Use Context.Tag for library APIs |

---

## Migration Guide

### Old Pattern -> Context.Tag

```typescript
// OLD: loose interface + function
export interface FooService { doThing: () => Effect.Effect<A> }
export const FooTag = Context.Tag<FooService>()
export function makeFoo(dep: Dep): FooService { return { ... } }
export const FooLive = Layer.effect(FooTag, Effect.map(DepTag, makeFoo))

// NEW: class-based Context.Tag
export class Foo extends Context.Tag("app/Foo")<Foo, {
  readonly doThing: () => Effect.Effect<A>
}>() {
  static readonly Live: Layer.Layer<Foo, never, Dep> = Layer.effect(
    Foo,
    Effect.gen(function* () {
      const dep = yield* Dep
      return { doThing: () => Effect.succeed(...) }
    })
  )
}
```

### When to Convert to Effect.Service

Only convert to `Effect.Service` when:
1. Single implementation (not library code)
2. Want auto-generated `.Default` layer
3. Simple dependency composition via `dependencies:`

```typescript
// App service with Effect.Service
export class AppCache extends Effect.Service<AppCache>()("app/Cache", {
  effect: Effect.gen(function* () {
    const store = new Map()
    return {
      get: (key) => Effect.sync(() => store.get(key)),
      set: (key, value) => Effect.sync(() => store.set(key, value))
    }
  })
}) {}

// Usage: AppCache.Default is the layer
```
