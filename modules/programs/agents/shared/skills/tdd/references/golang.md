# Go Notes (Optional)

Use this when the project is Go. Keep core TDD behavior-first.

## Interface Design

- Define interfaces at the consumer side, keep them minimal.
- Pass dependencies into constructors/functions, avoid hidden globals.
- Keep packages focused, small public surface, deep internals.

## Testing Style

- Prefer table-driven tests for behavior matrices.
- Use subtests with `t.Run(...)` to isolate cases.
- Use `httptest` for HTTP boundaries, keep domain tests transport-agnostic.

## Error and Data Design

- Return explicit errors, assert with `errors.Is` and `errors.As`.
- Check behavior and outputs, not internal call order.
- Keep edge concerns (network, disk, env) outside core domain functions.

## Determinism

- Inject clock/randomness as function params or tiny interfaces.
- Avoid package-level mutable state in tests and production code.
