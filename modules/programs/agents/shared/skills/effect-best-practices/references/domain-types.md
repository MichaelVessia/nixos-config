# Domain Types & Schema Patterns

## Research Resources

```bash
# Clone Effect source: git clone https://github.com/Effect-TS/effect <effect-repo>

# Schema.Class patterns
rg "Schema\.Class" <effect-repo>/packages/cluster/src
rg "Schema\.Class" <effect-repo>/packages/workflow/src

# Branded types
rg "Schema\.brand|Brand\." <effect-repo>/packages/cluster/src

# Request/Response patterns
rg "Schema\.TaggedRequest" <effect-repo>/packages/cluster/src
```

---

## Schema.Class (Domain Entities)

**Use for domain value objects and entities that need serialization.**

### From @effect/cluster

```typescript
// RunnerAddress.ts - value object with equality
const SymbolKey = "@effect/cluster/RunnerAddress"

export class RunnerAddress extends Schema.Class<RunnerAddress>(SymbolKey)({
  host: Schema.String,
  port: Schema.Number
}) {}

// EntityAddress.ts - composite address
const SymbolKey = "@effect/cluster/EntityAddress"

export class EntityAddress extends Schema.Class<EntityAddress>(SymbolKey)({
  entityType: Schema.String,
  entityId: Schema.String,
  shardGroup: ShardGroup
}) {}

// Runner.ts - entity with nested types
const SymbolKey = "@effect/cluster/Runner"

export class Runner extends Schema.Class<Runner>(SymbolKey)({
  address: RunnerAddress,
  status: Schema.Literal("running", "draining", "stopped"),
  registeredAt: Schema.Number
}) {}

// PodStatus from K8sHttpClient.ts - external API types
export class PodStatus extends Schema.Class<PodStatus>("@effect/cluster/K8sHttpClient/PodStatus")({
  phase: Schema.String,
  podIP: Schema.String.pipe(Schema.optionalWith({ default: () => "" }))
}) {}

export class Pod extends Schema.Class<Pod>("@effect/cluster/K8sHttpClient/Pod")({
  metadata: Schema.Struct({
    name: Schema.String,
    namespace: Schema.String
  }),
  status: Schema.optional(PodStatus)
}) {}
```

### Key Features

1. **Symbol key** - unique identifier for the class
2. **Built-in equality** - instances compare by value
3. **JSON serialization** - encode/decode built-in
4. **Schema validation** - runtime checks
5. **Type inference** - TypeScript types derived

### Usage Patterns

```typescript
// Create instance
const addr = new RunnerAddress({ host: "localhost", port: 8080 })

// Encode to JSON
const json = Schema.encodeSync(RunnerAddress)(addr)
// { "_tag": "@effect/cluster/RunnerAddress", "host": "localhost", "port": 8080 }

// Decode from JSON
const decoded = Schema.decodeUnknownSync(RunnerAddress)(json)

// Equality
addr === new RunnerAddress({ host: "localhost", port: 8080 })  // true (structural)
```

---

## Branded Types

**Use for type-safe IDs and domain primitives.**

### From @effect/cluster

```typescript
// EntityId.ts
import type { Brand } from "effect/Brand"

export type EntityId = string & Brand<"EntityId">

export const EntityId = Schema.String.pipe(
  Schema.brand("EntityId")
)

// ShardId.ts - branded number
export type ShardId = number & Brand<"ShardId">

export const ShardId = Schema.Number.pipe(
  Schema.brand("ShardId")
)

// Usage with validation
const makeShardId = (group: string, value: number): ShardId =>
  ShardId.make(value)  // throws if invalid
```

### Branded with Transformation

```typescript
// Snowflake.ts - complex branded type
export type Snowflake = bigint & Brand<"Snowflake">

// Parse from string
export const SnowflakeFromString = Schema.transformOrFail(
  Schema.String,
  Schema.BigIntFromSelf.pipe(Schema.brand("Snowflake")),
  {
    decode: (s) => {
      try {
        return ParseResult.succeed(BigInt(s) as Snowflake)
      } catch {
        return ParseResult.fail(new ParseResult.Type(Schema.BigInt.ast, s))
      }
    },
    encode: (n) => ParseResult.succeed(String(n))
  }
)
```

---

## Schema.TaggedRequest (RPC Messages)

**Use for request/response protocols.**

### From @effect/cluster tests

```typescript
import { Rpc, RpcSchema } from "@effect/rpc"
import * as Schema from "effect/Schema"
import * as PrimaryKey from "effect/PrimaryKey"

// Simple request
export class GetUser extends Schema.TaggedRequest<GetUser>()("GetUser", {
  success: User,
  failure: Schema.Never,
  payload: { id: Schema.Number }
}) {}

// Request with primary key (for deduplication)
export class StreamWithKey extends Schema.TaggedRequest<StreamWithKey>()("StreamWithKey", {
  success: RpcSchema.Stream({
    success: Schema.Number,
    failure: Schema.Never
  }),
  failure: Schema.Never,
  payload: { key: Schema.String }
}) {
  // PrimaryKey for request deduplication
  [PrimaryKey.symbol]() {
    return this.key
  }
}

// Request with custom failure type
export class SaveUser extends Schema.TaggedRequest<SaveUser>()("SaveUser", {
  success: User,
  failure: ValidationError,
  payload: { user: User }
}) {}
```

### Entity Protocol Definition

```typescript
// From TestEntity.ts
export const TestEntity = Entity.make("TestEntity", [
  Rpc.make("GetUser", {
    success: User,
    payload: { id: Schema.Number }
  }),
  Rpc.make("GetUserVolatile", {
    success: User,
    payload: { id: Schema.Number }
  }).annotate(ClusterSchema.Persisted, false),
  Rpc.make("Never"),  // No success, no failure, no payload
  Rpc.make("RequestWithKey", {
    payload: { key: Schema.String },
    primaryKey: ({ key }) => key  // Inline primary key
  }),
  Rpc.fromTaggedRequest(StreamWithKey),  // From Schema.TaggedRequest
  Rpc.make("GetAllUsers", {
    success: User,
    payload: { ids: Schema.Array(Schema.Number) },
    stream: true  // Streaming response
  })
]).annotateRpcs(ClusterSchema.Persisted, true)
```

---

## Workflow Schemas

### From @effect/workflow

```typescript
// Workflow definition with schemas
const MyWorkflow = Workflow.make("MyWorkflow", {
  // Payload schema - what gets passed in
  payload: Schema.Struct({
    userId: Schema.String,
    action: Schema.Literal("create", "update", "delete")
  }),
  // Success schema - what gets returned
  success: Schema.Struct({
    result: Schema.String,
    timestamp: Schema.Number
  }),
  // Error schema - what can fail
  failure: Schema.Union(
    ValidationError,
    NotFoundError
  )
})
```

---

## Common Schema Patterns

### Optional with Default

```typescript
export class Config extends Schema.Class<Config>("Config")({
  timeout: Schema.Number.pipe(
    Schema.optionalWith({ default: () => 5000 })
  ),
  retries: Schema.Number.pipe(
    Schema.optionalWith({ default: () => 3 })
  )
}) {}

// Both work:
new Config({})  // { timeout: 5000, retries: 3 }
new Config({ timeout: 10000 })  // { timeout: 10000, retries: 3 }
```

### Literal Union (Enum-like)

```typescript
export const Status = Schema.Literal("pending", "running", "completed", "failed")
export type Status = typeof Status.Type

export class Job extends Schema.Class<Job>("Job")({
  id: Schema.String,
  status: Status
}) {}
```

### Nested Structures

```typescript
export class Address extends Schema.Class<Address>("Address")({
  street: Schema.String,
  city: Schema.String,
  zip: Schema.String
}) {}

export class Person extends Schema.Class<Person>("Person")({
  name: Schema.String,
  address: Address,  // Nested Schema.Class
  tags: Schema.Array(Schema.String)
}) {}
```

### Recursive Types

```typescript
interface TreeNode {
  value: string
  children: ReadonlyArray<TreeNode>
}

const TreeNode: Schema.Schema<TreeNode> = Schema.suspend(() =>
  Schema.Struct({
    value: Schema.String,
    children: Schema.Array(TreeNode)
  })
)
```

---

## Encoding/Decoding

### Sync Operations

```typescript
// Decode unknown -> typed (throws on failure)
const user = Schema.decodeUnknownSync(User)(json)

// Encode typed -> JSON (throws on failure)
const json = Schema.encodeSync(User)(user)

// Validate (returns boolean)
const isValid = Schema.is(User)(maybeUser)
```

### Effect Operations

```typescript
// Decode with Effect error channel
const decodeUser = Schema.decodeUnknown(User)
// Type: (u: unknown) => Effect<User, ParseError>

// Usage in Effect.gen
const user = yield* Schema.decodeUnknown(User)(json)
```

### Parse with Custom Errors

```typescript
// Map parse errors to domain errors
const parseUser = (json: unknown) =>
  Schema.decodeUnknown(User)(json).pipe(
    Effect.mapError((parseError) =>
      new ValidationError({
        field: "user",
        expected: "User",
        received: json
      })
    )
  )
```

---

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| Plain interfaces for domain types | Use `Schema.Class` |
| String IDs without branding | Use `Schema.brand()` |
| Manual JSON parsing | Use `Schema.decodeUnknown` |
| `as Type` casts | Use Schema decode/encode |
| Mutable domain objects | Schema.Class is immutable |
| No validation on boundaries | Decode at entry points |
