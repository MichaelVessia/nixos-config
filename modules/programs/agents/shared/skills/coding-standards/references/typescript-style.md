## TypeScript style and safety

Use strict TypeScript settings where practical:

- `strict: true`
- `noUncheckedIndexedAccess: true`
- `exactOptionalPropertyTypes: true`
- `noImplicitOverride: true`
- `noFallthroughCasesInSwitch: true`

Prefer immutable values:

```ts
type CreateUserInput = {
  readonly email: EmailAddress;
  readonly roles: ReadonlyArray<Role>;
};
```

Mutation is acceptable inside localized imperative shell code, performance-sensitive internals, builders, or adapters when hidden behind a precise interface.

### Casts, `any`, and non-null assertions

Avoid:

- `any`
- non-null assertions (`!`)
- casts with `as Type`

`as const` is fine.

Rare exceptions are allowed for highly generic helpers, branding internals, interop boundaries, or combinators where TypeScript cannot express the invariant.

Any non-`as const` cast requires a Rust-like safety comment:

```ts
// SAFETY: TypeScript cannot express the brand. parseEmailAddress checked the normalized string before branding. Callers cannot construct EmailAddress except through this parser.
return normalized as EmailAddress;
```

Rare `any` also requires a targeted oxlint ignore and justification:

```ts
// oxlint-disable-next-line no-explicit-any -- SAFETY: This helper preserves arbitrary function parameters; TypeScript cannot express this variadic constraint without any.
type Fn = (...args: any[]) => unknown;
```

Do not use `!`. Branch, parse, or refine instead.

## Imports, exports, and files

Prefer direct imports from the file that owns the abstraction. Avoid barrel files / `index.ts` re-export layers by default.

For domain modules, namespace imports often preserve the module shape:

```ts
import * as EmailAddress from "./email-address";

EmailAddress.parse(input);
```

Use named imports for classes and focused shared helpers:

```ts
import { PasswordReset } from "./password-reset";
```

Use `import type` / `export type` for type-only imports and exports.

Export only what callers should use. Keep internal helpers unexported unless intentionally shared. Do not export internals just for tests.

Avoid TypeScript `namespace` unless there is a compelling interop reason.

Avoid vague files:

```txt
utils.ts
helpers.ts
common.ts
misc.ts
```

Use precise names:

```txt
email-address.ts
billing-period.ts
string-case.ts
array.ts
```

Tiny ubiquitous generic helpers/types may share one explicit module when no more precise owner exists. Appropriate contents include:

- `casesHandled`
- `shouldNeverHappen`
- `notYetImplemented`
- `Redacted`
- `Tags`, `ExtractTag`, and `ExcludeTag`
- common `Result` helpers when the project uses neither Effect nor an established typed-result abstraction
- broad type utilities

Keep only helpers justified by the target project. Keep domain and application policy with their owning modules.

No arbitrary file-size limits. Prefer cohesion and discoverability over small files for their own sake. Split when a file has multiple unrelated reasons to change or callers must understand unrelated concepts.

## Comments and JSDoc

Comments should explain invariants, trade-offs, non-obvious domain rules, and safety justifications. Avoid comments that narrate obvious code.

Every exported symbol from a JavaScript or TypeScript module requires JSDoc. Public methods and properties of an exported class also require JSDoc. Private and otherwise internal code requires documentation only when its complexity warrants it. Put documentation on the original declaration; re-exports do not need duplicate documentation.

Do not use `@inheritDoc`, `@inherit`, or similar inheritance tags. Write the required documentation explicitly on each symbol or member.

Use standard JSDoc syntax:

```ts
/**
 * Parse an email address from untrusted input.
 *
 * @param input - The untrusted string to parse.
 * @returns A parsed email address, or `InvalidEmailAddress` when the input is invalid.
 */
export function parse(input: string): Result<EmailAddress, InvalidEmailAddress>;
```

For generics:

```ts
/**
 * Map the success value of a result.
 *
 * @template T - The original success type.
 * @template U - The mapped success type.
 * @template E - The error type.
 * @param result - The result to map.
 * @param fn - The function applied to the success value.
 * @returns A result with the mapped success value, or the original error.
 */
export function map<T, U, E>(result: Result<T, E>, fn: (value: T) => U): Result<U, E>;
```

Use `@throws` only for unrecoverable defects, framework-required behavior, or temporary `notYetImplemented` paths. Do not document expected typed errors as throws.

For complex exported object types, document fields when helpful:

```ts
/** Input required to create a user. */
export type CreateUserInput = {
  /** The actor creating the user. */
  readonly actor: AdminUser;

  /** The parsed email address for the new user. */
  readonly email: EmailAddress;
};
```

## Configuration and resources

Parse environment/config at startup or the earliest boundary into typed config with branded/redacted values where appropriate. Return known configuration failures as tagged error values. The composition root should report a safe startup message and terminate rather than treating invalid configuration as an internal defect.

Do not read `process.env` throughout the app. Missing or invalid config is a startup failure with useful, safe context.

Avoid top-level side effects except in true entrypoint/bootstrap files. Modules should not start servers, open connections, read env, register handlers, or perform I/O at import time.

Resource creation and cleanup should be explicit and owned by bootstrap/imperative shell code or Effect layers when using Effect.

Avoid mutable singletons/global state. Constants and pure lookup tables are fine. If a singleton is required by a framework/runtime, isolate it at the boundary.

Inject `Clock` / `Random` services into dependency-bearing modules. Pure domain functions may accept explicit `now` / random values.
