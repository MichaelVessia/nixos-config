## Modules and abstractions

**Domain Module**, **Application Service Module**, and **Adapter Module** name responsibilities, not required folders, suffixes, or TypeScript constructs. A module may be a function, object, class, file, or package with a cohesive public interface. Use the roles at any scale; do not create three layers when the behavior does not need them.

The normal dependency and call flow for an operation with application policy or effects is:

```txt
external input -> inbound Adapter -> Application Service -> Domain Module
                                           |
                                           +-> application-owned port
                                                 -> outbound Adapter -> external system
```

An inbound Adapter may call a Domain Module directly only for a pure operation with no authorization, application policy, persistence, external calls, or effect sequencing:

```txt
external input -> inbound Adapter -> Domain Module
```

The composition root constructs concrete Adapters and supplies them to Application Services. Dependencies point inward: Domain Modules know neither services nor Adapters; Application Services know application-owned port contracts, not concrete technologies; Adapters depend on those contracts and translate at the edge.

### Choosing a role

Classify code by the responsibility that would make it change:

- A business meaning, invariant, calculation, or legal state transition changes: **Domain Module**.
- An application operation's policy, authorization, or effect sequence changes: **Application Service Module**.
- A protocol, framework, database, runtime, or third-party API changes: **Adapter Module**.
- Only construction, configuration, or resource wiring changes: **composition root**.

Split an abstraction when it owns more than one of these reasons to change. Do not split code merely to satisfy the taxonomy: a pure operation may need only a Domain Module, while a simple boundary may call an Application Service with no new domain type.

### Applying the roles in any codebase

For a new feature or a local refactor:

1. Trace one caller-visible operation from ingress to every effect.
2. Put intrinsic meanings, invariants, calculations, and transitions in Domain Modules.
3. Put application policy and effect ordering in an Application Service; define its dependencies as narrow ports.
4. Put each protocol or technology translation in an inbound or outbound Adapter.
5. Wire concrete Adapters to ports at the composition root.
6. Verify each role through its public seam: domain results, application outcomes, and boundary records/responses.

Apply these responsibilities inside the project's existing layout and framework vocabulary. Migrate mixed code only across the feature's required semantic surface; otherwise contain the old convention at an Adapter seam rather than forcing a broad rewrite.

For example, in password reset: `EmailAddress` and `ResetToken` are Domain Modules; `PasswordReset` is the Application Service; an HTTP route is an inbound Adapter; Postgres and email-provider implementations are outbound Adapters; bootstrap performs the wiring.

### Deep modules

A deep module hides substantial behavior, invariants, policy, sequencing, or translation behind a cohesive, low-burden interface. Low-burden does not necessarily mean few functions.

Avoid shallow abstractions that merely forward calls, mirror tables, rename another API, or expose implementation steps.

Use the deletion test:

- if deleting the module makes complexity disappear, it was probably pass-through waste
- if deleting it spreads complexity across callers, it was probably earning its keep

### Domain Modules

A **Domain Module** is a pure, type-centric abstract data type in the OCaml tradition. It centers one primary domain type or tightly related type family and owns what values mean and which operations are legal.

Use one when the code has a meaningful domain distinction, invariant, calculation, decision, or lifecycle. Keep a primitive or local pure function when introducing a domain abstraction would prevent no realistic misuse and centralize no meaningful rule.

A Domain Module should:

- co-locate its type, supporting types, parsers, smart constructors, combinators, predicates, legal transitions, domain projections, formatting, and test generators as applicable
- return refined values from parsers and constructors so callers cannot create invalid instances
- express expected failures as precise values
- remain deterministic and independent of I/O, frameworks, persistence, ambient time, randomness, and mutable global state

It may define pure permission decisions over parsed domain values. It should not authenticate callers, gather authorization context, enforce permissions while carrying out an application operation, choose effect order, query storage, call a network, or expose transport/persistence DTOs. Callers use its operations instead of recreating its checks or branding values with casts.

Example:

```ts
// email-address.ts

/** A parsed, normalized email address. */
export type EmailAddress = Brand<string, "EmailAddress">;

/** Parse an email address from untrusted input. */
export function parse(input: string): Result<EmailAddress, InvalidEmailAddress>;

/** Render an email address as a string. */
export function toString(email: EmailAddress): string;

/** Compare two email addresses for equality. */
export function equals(left: EmailAddress, right: EmailAddress): boolean;
```

Domain Modules may use plain functions, immutable value classes, or static-style classes when cohesive. If using classes:

- construct through `parse` / `make` / smart constructors
- make invalid instances unconstructable
- keep fields readonly/immutable from callers
- keep methods cohesive over that value
- do not hide dependencies or I/O inside domain value classes
- avoid inheritance for domain behavior

### Application Service Modules

An **Application Service Module** owns one cohesive application operation or capability, such as `PasswordReset`, `Invitations`, or `SubscriptionLifecycle`. It applies application policy and sequences effects through narrow, application-owned ports while delegating intrinsic business rules to Domain Modules.

Use one when an operation must coordinate authorization, domain decisions, persistence, external calls, transactions, messages, time, IDs, or telemetry—or when the same operation must be callable from multiple entrypoints. A direct Domain Module call is enough when no application policy or effect orchestration exists.

An Application Service should:

- accept and return application/domain types with precise expected-error unions
- define the smallest meaningful ports required by the operation
- receive ports, configuration, clocks, randomness, and similar capabilities explicitly
- own which effects occur, under what policy, and in what order
- remain independent of HTTP, CLI, queue, ORM, vendor SDK, and runtime types

It should not parse protocol envelopes, render responses, execute SQL, translate vendor DTOs, or duplicate Domain Module invariants. Prefer constructor injection for dependency-bearing classes; in Effect codebases, use services/tags/layers. Avoid dependency bags passed into every call.

There is no arbitrary method limit. Split methods that represent unrelated capabilities, change for different reasons, or require unrelated dependencies. Avoid vague names such as `Manager`, `Processor`, `Helper`, or generic `UserService` unless established by the project.

### Adapter Modules

An **Adapter Module** owns one boundary's translation and technology mechanics. Use one whenever application code crosses a framework, protocol, serialization, process, persistence, runtime, or third-party boundary.

There are two directions:

- An **inbound Adapter** parses an external request/event/command, invokes an Application Service or a directly callable pure Domain Module as described above, and projects its result into the external protocol. Examples: HTTP route, GraphQL resolver, CLI command, queue consumer.
- An **outbound Adapter** implements an Application Service port using a concrete technology and translates raw records, SDK values, and external failures into application/domain types and typed errors. Examples: Postgres store, Stripe client, email sender, system clock.

An Adapter should own schema/DTO translation, framework lifecycle, external error classification, and safe diagnostics for its boundary. It may retry a short-lived technical failure only when the operation is safely repeatable and the retry does not change the port's meaning. It should not decide business eligibility, authorization policy, legal state transitions, or application-operation ordering. Keep raw external types inside the Adapter or composition root.

A port is not an Adapter. A port is the application-owned contract that states what an operation needs; an outbound Adapter is one replaceable implementation. Do not add an Adapter that only forwards the same shape to another internal module without hiding real translation or mechanics.

### Composition root

The composition root parses environment and configuration, acquires resources, constructs concrete Adapters, and injects them into Application Services. Keep framework bindings and concrete wiring here; do not turn the composition root into a place for domain rules, application policy, or reusable boundary translation.

## Application-owned ports and Adapter reuse

Define ports beside the Application Service that needs them and in the application's language, not the provider's language. Depend on the smallest meaningful capability the operation uses; let a cohesive concrete Adapter be wider. Port inputs, outputs, and errors must be application/domain types rather than raw rows, SDK objects, or framework values.

Because TypeScript is structurally typed, this works well:

```ts
type UsersForPasswordReset = {
  findActiveByEmail(email: EmailAddress): Promise<Result<ActiveUser, UserLookupError>>;
};

export class PasswordReset {
  constructor(private readonly users: UsersForPasswordReset) {}
}
```

A wider adapter can satisfy it:

```ts
export class PostgresUsers {
  findActiveByEmail(...) { ... }
  findById(...) { ... }
  updateProfile(...) { ... }
}
```

This avoids both mega-repositories and one-method adapter sprawl.

### Adapter reuse audit

Before creating a new adapter or service, agents must audit existing adapters/services.

Prefer, in order:

1. Reuse an existing adapter as-is through a narrow dependency type.
2. Extend an existing adapter if the new method fits its existing cohesive capability and changes for the same reason.
3. Create a new adapter only when reuse/extension would create bad coupling or an accidental interface.

Do not require an ADR for a routine feature-level Adapter or Application Service. Create an ADR when the new module introduces a lasting architectural boundary, shared pattern, provider strategy, or deliberate exception to these standards. The ADR should explain:

- what existing Adapters or Application Services were checked
- why reuse or extension did not fit
- why the new boundary or pattern is a separate cohesive capability

### Repositories and persistence

Avoid repository-per-table by default.

Repository-like adapters are acceptable when they represent a cohesive domain persistence capability. They should expose meaningful domain operations and return parsed domain types / typed errors, not raw rows and ORM errors.

Treat raw database rows and ORM models as infrastructure DTOs. Parse them before application/core logic. Keep SQL/ORM details inside infrastructure adapters or persistence modules.

## Functional core, imperative shell, and entrypoints

Domain Modules form the functional core. Application Service Modules and Adapter Modules form the imperative shell, but only Adapters contain technology-specific concerns. This keeps the same application operation reusable across REST, CLI, GraphQL, workers, and other entrypoints.

The functional core contains domain parsers, invariants, state transitions, calculations, combinators, and decision functions. It avoids I/O, hidden dependencies, ambient time/randomness, thrown expected failures, and framework-specific concerns.

The imperative shell has two distinct responsibilities:

- Application Services apply application policy and sequence effects through explicit ports.
- Adapters parse or project boundary values, classify external failures, and perform concrete I/O.

Entrypoint Adapters should be thin protocol translation layers. They parse protocol-specific input, call Domain Module parsers to obtain refined values, invoke an Application Service when application policy or effects are involved, and render protocol-specific output. A pure operation may call a Domain Module directly as described above. Do not duplicate business rules in controllers, resolvers, commands, or handlers.

Within authentication and authorization, inbound Adapters verify boundary credentials and produce a parsed identity such as `Principal`, `Session`, or `CommandActor`. Domain Modules may define pure permission decisions over parsed domain values. Application Services gather the required context and enforce those decisions while carrying out an application operation. Adapters project missing or invalid credentials and denied operations into protocol-specific outcomes; they do not define permission policy.

## Workflows, transactions, and idempotency

Use ordinary function calls or database transactions for simple single-boundary operations.

Use a saga or durable workflow when progress must survive process loss or redelivery, or when the operation requires long delays, compensation, resumability, timers, human approval, cross-service coordination, or multiple transaction boundaries. A short-lived retry by itself does not require durable workflow machinery.

Adapters own safe, short-lived technical retries. Application Services decide whether an application operation should be attempted again. Durable workflows own retries that must survive crashes, delays, or redelivery.

Do not hold database transactions open across network calls or long-running operations.

Any externally observable mutation or state transition that may be retried needs an explicit idempotency strategy:

- idempotency key
- natural unique constraint
- deduplication record
- state-machine transition guard
- transactional outbox/inbox

Retrying should not rely on “probably safe” side effects.
