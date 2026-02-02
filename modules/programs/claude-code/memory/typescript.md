# TypeScript Guidelines

## Type Safety (Non-Negotiable)

- **No `any`**: Never use `any`. Use `unknown` + type guards if type is truly unknown.
- **No `as Type`**: Type assertions hide bugs. Use type guards or fix the type at its source.
- **No `!` (non-null assertion)**: If something might be null, handle it explicitly.

## Browser Assumptions

- Target modern browsers only: ES2022+, no IE11
- Safe to use: optional chaining, nullish coalescing, Promise.allSettled, BigInt
- No polyfills needed for standard APIs

## Prefer `satisfies` Over Type Annotations

For object literals, `satisfies` validates the type while preserving the narrower inferred type:

```typescript
// Good: preserves literal types
const config = {
  mode: "production",
  port: 3000,
} satisfies Config;

// Worse: widens to Config type
const config: Config = {
  mode: "production",
  port: 3000,
};
```

## Immutability

- Use `readonly` for arrays/objects that shouldn't be mutated
- Prefer `ReadonlyArray<T>` in function parameters
- Use `as const` for literal object/array constants

## Error Handling

- Define explicit error types, don't throw raw strings
- Use discriminated unions for result types when appropriate
- Catch at boundaries, not everywhere
