## Testing

Add an end-to-end test whenever the behavior can be exercised through its real public entrypoint in the normal test environment without unreliable third parties or unreasonable setup, runtime, or cost. Add lower-level tests when they provide extra coverage for important cases.

Prefer confidence-oriented tests:

1. end-to-end tests through real public entrypoints whenever possible
2. integration tests through real seams
3. focused/property tests for pure Domain Modules
4. unit tests when they test meaningful behavior, not implementation details

Never use `vi.mock` or `jest.mock` for module mocking. Use real seams:

- constructor-injected interfaces/classes
- Effect services/layers
- local database substitutes such as SQLite
- in-memory adapters when behavior is simple
- fake external adapters when needed

Prefer tests that assert observable input/output behavior:

- returned value/error
- persisted state
- emitted event/message
- rendered response
- sent email record in a fake/local adapter

Avoid spy-driven tests like `expect(sendEmail).toHaveBeenCalledWith(...)` unless the interaction itself is the only observable behavior.

For persistence behavior, prefer SQLite/local DB-backed tests over hand-rolled in-memory fakes when SQL/schema/transaction behavior matters.

### Property tests and arbitraries

Use `fast-check` where properties are clearer than examples, especially for:

- parsers/smart constructors
- branded/refined types
- state machines
- serialization roundtrips
- normalization/idempotence
- lawful combinators

Use arbitraries for mock/test data generation. Prefer exporting arbitraries near the domain module they support:

```txt
src/billing/
  invoice-number.ts
  invoice-number.test.ts
  invoice-number.arbitrary.ts
```

Tests should not bypass parsers, smart constructors, or invariants.
