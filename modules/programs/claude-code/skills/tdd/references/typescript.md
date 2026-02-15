# TypeScript Notes (Optional)

Use this only when the project is TypeScript. Core TDD guidance stays language-agnostic.

## Test Framework Mapping

- `assert ...` maps to `expect(...)` in Jest/Vitest.
- `spy on ...` maps to `vi.spyOn(...)` or `jest.spyOn(...)`.
- Test cases map to `test(...)` or `it(...)`.

## Mocking in TypeScript

- Favor interface-driven dependencies at boundaries.
- Mock the boundary interface, not internal collaborators.
- Keep operation-specific methods (`getUser`, `createOrder`) over a single generic `request`.

## Type Safety During TDD

- Keep strict compiler settings on while iterating.
- Prefer explicit domain types over primitive strings/numbers in business logic.
- Avoid weakening types just to make tests pass.
