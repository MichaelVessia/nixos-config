## Errors and failures

### Expected failures are values

Every known failure mode should appear in the return type as a custom tagged error, even when the immediate caller cannot recover. A caller must handle the error or return it upward. At the outermost boundary, translate it into a valid outcome such as an HTTP response, CLI exit code, retry decision, dead letter, or startup error message.

Known failures include domain, parsing, authorization, integration, I/O, persistence, configuration, and workflow failures.

Preferred order:

1. Effect, when the codebase already uses Effect.
2. The codebase's established typed-result abstraction, when one exists.
3. Otherwise, a small local tagged union:

```ts
type Result<T, E extends Error> =
  | { readonly _tag: "ok"; readonly value: T }
  | { readonly _tag: "err"; readonly error: E };
```

Prefer:

```ts
Promise<Result<User, UserLookupError>>
```

not:

```ts
Promise<User> // rejects for ordinary lookup/storage failures
```

Promise rejection is equivalent to throwing. Catch unclassified third-party rejection inside the owning Adapter and translate it into a known tagged error before it crosses the Adapter boundary. Rejection may escape application code only for a defect.

### Defects may throw or panic

Throw or panic only when a defect makes correct execution impossible, not merely because the current caller has no recovery strategy. Defects include:

- violated internal invariants
- impossible branches
- temporary `notYetImplemented` paths
- catastrophic runtime conditions

Known configuration failures are values; the composition root reports them safely and terminates startup.

Use established shared defect helpers where available:

```ts
export function casesHandled(unexpectedCase: never): never;
export function shouldNeverHappen(msg?: string): never;
export function notYetImplemented(msg?: string): never;
```

Use `casesHandled` for exhaustive union handling. Avoid names like `absurd` or one-off `assertNever` helpers when the project already has these helpers.

### Custom errors

Expected failures should use custom tagged errors, generally extending:

- `Error`
- `Schema.TaggedErrorClass` in Effect codebases

Custom errors should include:

- stable tag using 'as const'
- useful message
- structured contextual fields
- safe telemetry fields
- optional `cause: unknown`

Example:

```ts
export class UserStoreUnavailable extends Error {
  readonly _tag = "UserStoreUnavailable" as const;

  constructor(
    readonly operation: "findActiveByEmail",
    readonly provider: "postgres",
    readonly cause: unknown,
  ) {
    super(`User store unavailable during ${operation}`);
  }
}
```

Keep error unions precise at module boundaries:

```ts
Result<User, UserNotFound | UserStoreUnavailable>
```

Avoid broad `AppError`-style types except near entrypoints, orchestration, logging, and rendering layers.

## Sensitive data, telemetry, and debugging

Prefer end-to-end structured tracing across requests, jobs, workflows, application modules, adapters, and external calls.

Tracing/logging should make failures diagnosable with safe fields:

- domain IDs
- operation names
- dependency/provider names
- state tags
- retry counts
- typed error tags
- safe summaries

Do not put secrets in errors, traces, logs, or snapshots.

Use a `Redacted<T>` wrapper for sensitive values such as tokens, API keys, passwords, raw credentials, and secrets. Prefer Effect's `Redacted.Redacted` in Effect codebases or a local shared `Redacted<T>` wrapper.

Wrap sensitive values at the boundary and unwrap only where the raw value is needed, usually inside an adapter making an external call.

## Parse, don't validate

Boundary code should turn unknown or less-structured input into application or domain types before it enters inner code.

Use a separate protocol projection only when its shape or meaning differs enough to be useful. `DTO` describes a boundary role in prose; never use `DTO` or `Dto` in a symbol name. Name the symbol after its actual protocol or persistence meaning, such as `CreateUserRequest`, `StripeCustomerResponse`, or `UserRecord`:

```ts
unknown -> CreateUserRequest -> CreateUserInput -> EmailAddress/UserId/etc.
```

Otherwise, parse directly into the application input:

```ts
unknown -> CreateUserInput
```

Do not pass a schema-inferred transport shape throughout the application:

```ts
unknown -> z.infer<typeof CreateUserSchema>
```

Use names that preserve meaning:

- `parseX(input): Result<X, ParseXError>` for untrusted or less-structured input
- `makeX(...)` / `createX(...)` for smart constructors from already-typed pieces
- `isX(value): value is X` for true predicates
- `assertX(...)` rarely, mostly at tests/framework boundaries

Avoid `validateX` when the function returns a refined value. It parsed something.

### Schemas

Use schema libraries as boundary parsers, not as ad-hoc validators sprinkled through core logic.

Preference:

- use the repo's established schema library if one exists
- use Effect Schema in Effect codebases
- prefer Standard Schema compatibility for generic helpers
- otherwise prefer Zod 4
- use hand-written smart constructors/parsers for small domain types when clearer

Schema parsing should produce refined/domain types and typed custom errors where practical.

## Branded types and correct construction

Use branded/refined types when they prevent realistic misuse or invalid construction, especially for:

- IDs: `UserId`, `OrgId`, `WorkflowId`
- parsed strings: `EmailAddress`, `NonEmptyString`, `Url`
- constrained numbers: `PositiveInt`, `Cents`, `Percentage`
- units: `Milliseconds`, `Bytes`, `UsdCents`

Construct branded values through parsers or smart constructors. Avoid passing raw strings/numbers where a domain type exists.

Avoid optional/null/undefined values in functions that require a value. Push optionality outward. Branch or parse before calling.

Avoid `Partial<T>` as an application/domain input unless partiality is the real domain concept. Prefer explicit input types for each operation.

## State machines and boolean blindness

When an entity has meaningful lifecycle states, model them with tagged unions or equivalent value classes.

Prefer:

```ts
type Invoice =
  | { readonly _tag: "Draft"; readonly id: InvoiceId; readonly lines: NonEmptyArray<LineItem> }
  | { readonly _tag: "Sent"; readonly id: InvoiceId; readonly sentAt: Instant }
  | { readonly _tag: "Paid"; readonly id: InvoiceId; readonly paidAt: Instant };
```

Avoid:

```ts
type Invoice = {
  readonly isSent: boolean;
  readonly isPaid: boolean;
  readonly sentAt?: Date;
  readonly paidAt?: Date;
};
```

Avoid boolean parameters that control behavior:

```ts
createUser(input, true);
```

Prefer named options or domain types:

```ts
createUser(input, { emailVerification: "skip" });
```

Booleans are fine as clear predicate return values:

```ts
isExpired(token): boolean;
hasPermission(user, permission): boolean;
```
