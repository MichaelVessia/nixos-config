---
name: coding-standards
description: Correct-by-construction TypeScript standards. Use for TypeScript engineering or when another skill needs the user's coding standards.
license: MIT; see LICENSE.txt
metadata:
  author: dmmulroy
  source: https://github.com/dmmulroy/skills/tree/main/coding-standards
---
These standards describe how to design and write TypeScript code in this codebase. They are especially intended for agents: inspect existing code before adding patterns, libraries, Adapters, or abstractions, but apply these standards to all new and refactored behavior. Follow existing conventions only when they are compatible with these standards.

## Decision priority

When rules pull in different directions, use this order:

1. Preserve correctness, safety, and debuggability.
2. Apply these standards to all new code and to the full behavior being refactored.
3. Follow compatible project architecture and conventions.
4. Contain incompatible existing patterns at the nearest boundary rather than copying them into new code.
5. Avoid changing unrelated old code unless a broader migration is explicitly requested.
6. Document meaningful trade-offs with comments or ADRs.

## Core principles

- Prefer **errors as values** over `throw` / rejected promises for expected failures.
- **Parse don't validate**. Parse early and as close to composition or application roots as possible. Do not merely validate and throw away the information learned.
- Make **illegal states unrepresentable** where practical.
- Prefer **correct-by-construction** APIs over convention-based invariants.
- Use branded/refined/domain types when they prevent a realistic mistake, such as mixing identifiers or units, bypassing parsing, or constructing an invalid value.
- Prefer **composition over inheritance**.
- Prefer **imperative shell / functional core**.
- Design **deep, cohesive modules** with **low caller burden**.
- Test behavior through real seams; **avoid** module mocks and spy-driven tests.
- Keep code discoverable for humans and agents.

## Adapting to existing codebases

Before adding a new pattern or library, inspect the repo for existing choices around:

- error handling
- schema parsing
- dependency injection
- testing
- observability
- adapters/services
- module layout

Apply these standards to all new code and to the full behavior being refactored. Do not preserve weaker patterns merely for consistency. Keep unrelated old code unchanged and translate incompatible patterns at the nearest boundary.

For example, if existing code uses exception-style errors, do not rewrite the whole system for an unrelated change. Represent known failures as typed values in new or refactored code, then translate them at the boundary into the outcome required by the existing framework. Preserve existing logging, tracing, metrics, and error-reporting hooks.

## Reference map

Read only the references relevant to the changed behavior. Read multiple when a change crosses concerns.

- Expected failures, telemetry, parsing, schemas, branded types, and state machines: [errors-and-domain-modeling.md](references/errors-and-domain-modeling.md)
- Domain, application-service, Adapter, composition-root, persistence, workflow, and idempotency design: [architecture.md](references/architecture.md)
- End-to-end, integration, property, and lower-level testing: [testing.md](references/testing.md)
- Strict TypeScript, casts, imports, exports, files, JSDoc, configuration, and resources: [typescript-style.md](references/typescript-style.md)

## Quick agent checklist

Before coding:

- Read existing conventions for errors, schemas, tests, adapters, telemetry, and module layout.
- Classify each changed concern as Domain Module, Application Service Module, Adapter Module, or composition-root wiring.
- Reuse existing Domain Modules, Application Services, and Adapters before creating new ones.
- Define effect dependencies as narrow, application-owned ports; keep raw external types in Adapters or the composition root.
- Parse inputs at the edge and use domain types internally.
- Avoid raw DTOs, raw IDs, nullable bags, and `Partial<T>` in core/application logic.
- Prefer typed errors as values for new expected failures.
- Preserve existing observability/error mechanics.
- Test through public interfaces and real seams.
- Use `fast-check` arbitraries for generated test data when practical.
- Add JSDoc for exported symbols.
- Add an ADR only for a lasting architectural boundary, shared pattern, provider strategy, or deliberate exception discovered through the Adapter/Application Service reuse audit.
