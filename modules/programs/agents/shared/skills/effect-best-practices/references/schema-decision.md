# Schema.Class vs Schema.Struct Decision Matrix

## Quick Reference

| Use Schema.Class when... | Use Schema.Struct when... |
|--------------------------|---------------------------|
| Needs `Equal.symbol`/`Hash.symbol` | Plain DTO |
| Used as HashMap/HashSet key | No identity semantics |
| Has computed properties or methods | No behavior |
| Needs `PrimaryKey.symbol` | Decoded immediately |
| Part of discriminated union → TaggedClass | Never stored as keys |

**Default to Schema.Struct.** Most types are DTOs without behavior.

## Decision Tree

```
Is the type used as a key in HashMap/HashSet?
  YES → Schema.Class (implement Equal/Hash symbols)
  NO ↓

Does it need computed properties or methods?
  YES → Schema.Class
  NO ↓

Is it part of a discriminated union?
  YES → Schema.TaggedClass
  NO ↓

Use Schema.Struct
```

## Schema.Struct (Most Common)

For DTOs, config objects, state containers - anything without behavior.

```typescript
// Simple DTO
export const Limits = Schema.Struct({
  steps: Schema.Number.pipe(Schema.nonNegative()),
  rows: Schema.Number.pipe(Schema.nonNegative()),
  bytes: Schema.Number.pipe(Schema.nonNegative()),
})
export type Limits = typeof Limits.Type

// Nested structs
export const Capability = Schema.Struct({
  cap_id: CapId,
  issuer: PrincipalId,
  holder: PrincipalId,
  scope: Scope,  // Another Schema.Struct
  limits: Limits,
  expiry_tx: Schema.optional(TxTime),
})
export type Capability = typeof Capability.Type

// With refinements
export const TxTime = Schema.Struct({
  ctr: Schema.Number.pipe(
    Schema.finite(),
    Schema.int(),
    Schema.nonNegative(),
  ),
  pid: Schema.String,
})
export type TxTime = typeof TxTime.Type
```

## Schema.Class (When Behavior Needed)

Use when the type needs custom equality, hashing, or methods.

```typescript
// From @effect/cluster - needs equality for map keys
export class RunnerAddress extends Schema.Class<RunnerAddress>(
  "@effect/cluster/RunnerAddress"
)({
  host: Schema.NonEmptyString,
  port: Schema.Int,
}) {
  // Custom equality for use as HashMap key
  [Equal.symbol](that: RunnerAddress): boolean {
    return this.host === that.host && this.port === that.port
  }

  // Custom hashing
  [Hash.symbol]() {
    return Hash.cached(this, Hash.string(`${this.host}:${this.port}`))
  }

  // Computed property
  get endpoint(): string {
    return `${this.host}:${this.port}`
  }
}

// From @effect/cluster - needs PrimaryKey for storage
export class EntityAddress extends Schema.Class<EntityAddress>(
  "@effect/cluster/EntityAddress"
)({
  shardId: ShardId,
  entityType: EntityType,
  entityId: EntityId,
}) {
  [PrimaryKey.symbol](): string {
    return `${this.entityType}:${this.entityId}`
  }
}
```

## Schema.TaggedClass (Discriminated Unions)

For union variants that need automatic `_tag` discrimination.

```typescript
// Each variant is a TaggedClass
export class Appended extends Schema.TaggedClass<Appended>()(
  "Appended",
  {
    ledger: LedgerState,
    record_id: RecordId,
  }
) {}

export class AlreadyExists extends Schema.TaggedClass<AlreadyExists>()(
  "AlreadyExists",
  {
    ledger: LedgerState,
    record_id: RecordId,
  }
) {}

export class Quarantined extends Schema.TaggedClass<Quarantined>()(
  "Quarantined",
  {
    ledger: LedgerState,
    reason: Schema.String,
  }
) {}

// Union schema for serialization
export const AppendResult = Schema.Union(Appended, AlreadyExists, Quarantined)
export type AppendResult = typeof AppendResult.Type

// Usage - pattern matching works
const handle = (result: AppendResult) => {
  switch (result._tag) {
    case "Appended": return result.record_id
    case "AlreadyExists": return result.record_id
    case "Quarantined": return result.reason
  }
}
```

### TaggedClass with Methods

```typescript
export class AckChunk extends Schema.TaggedClass<AckChunk>()(
  "AckChunk",
  {
    id: SnowflakeFromString,
    address: EntityAddress,
    requestId: SnowflakeFromString,
  }
) {
  // Instance method for transformation
  withRequestId(requestId: Snowflake): AckChunk {
    return new AckChunk({ ...this, requestId })
  }
}
```

## Branded Types (Schema.brand)

For type-safe IDs without full class behavior.

```typescript
// Simple branded string
export const RecordId = Schema.String.pipe(Schema.brand("RecordId"))
export type RecordId = typeof RecordId.Type

// Usage
const id: RecordId = RecordId.make("sha256:abc123")

// With validation
export const ToolId = Schema.String.pipe(
  Schema.pattern(/^[a-z]+\.[a-z]+\.[a-z]+@\d+\.\d+\.\d+$/),
  Schema.brand("ToolId")
)
export type ToolId = typeof ToolId.Type
```

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Schema.Class for simple DTOs | Unnecessary overhead | Use Schema.Struct |
| String literal union in Struct | No type narrowing | Use TaggedClass for variants |
| Separate interface + schema | Drift, duplication | Combine into single schema |
| Schema.Class without Equal/Hash | No benefit over Struct | Use Struct instead |
| Phantom type `& { _tag }` | No runtime validation | Use Schema.brand |
| `as Type` casts | Bypasses validation | Use Schema.decodeUnknown |

## Migration Patterns

### Interface + Schema → Single Schema

```typescript
// BEFORE (two files or duplicated)
export interface VaultEntry {
  readonly cas_id: CasId
  readonly media_type: string
}
export const VaultEntrySchema = Schema.Struct({
  cas_id: CasId,
  media_type: Schema.String,
})

// AFTER (single source of truth)
export const VaultEntry = Schema.Struct({
  cas_id: CasId,
  media_type: Schema.String,
})
export type VaultEntry = typeof VaultEntry.Type
```

### Phantom Type → Schema.brand

```typescript
// BEFORE (compile-time only)
export type WorkflowId = string & { readonly _tag: "WorkflowId" }

// AFTER (runtime validation)
export const WorkflowId = Schema.String.pipe(Schema.brand("WorkflowId"))
export type WorkflowId = typeof WorkflowId.Type
```

### String Literal Union → TaggedClass

```typescript
// BEFORE (no narrowing, no per-variant data)
export interface Result {
  status: "success" | "failure"
  data?: unknown
  error?: string
}

// AFTER (proper discrimination)
export class Success extends Schema.TaggedClass<Success>()(
  "Success",
  { data: Schema.Unknown }
) {}

export class Failure extends Schema.TaggedClass<Failure>()(
  "Failure",
  { error: Schema.String }
) {}

export const Result = Schema.Union(Success, Failure)
export type Result = typeof Result.Type
```

## Serialization

All schema types (Struct, Class, TaggedClass) support encode/decode:

```typescript
// Decode from unknown (with validation)
const entry = Schema.decodeUnknownSync(VaultEntry)(json)

// Encode to JSON
const json = Schema.encodeSync(VaultEntry)(entry)

// In Effect context (returns Effect with ParseError)
const decoded = yield* Schema.decodeUnknown(VaultEntry)(json)
```
