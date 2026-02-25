# Rust Notes (Optional)

Use this when the project is Rust. Keep core TDD behavior-first.

## Interface Design

- Put boundaries behind traits (ports), keep domain logic generic over those traits.
- Prefer constructor injection over creating clients inside methods.
- Use small traits per capability, avoid large "god traits".

## Testing Style

- Test behavior through public functions and modules.
- Prefer realistic fakes that implement traits over heavy mocking.
- Use `#[test]` for sync logic, `#[tokio::test]` (or runtime equivalent) for async.

## Error and Data Design

- Return `Result<T, E>`, make `E` a domain error enum.
- Assert on semantic error variants, not string messages.
- Keep parsing/IO at edges, test core logic with plain values.

## Determinism

- Inject clock/random generators behind traits.
- Avoid direct `SystemTime::now()` or global randomness in core logic.
