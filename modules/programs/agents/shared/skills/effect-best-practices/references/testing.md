# Testing Patterns

## @effect/vitest Setup

```typescript
import { describe, it } from "@effect/vitest"
import { expect } from "vitest"
import * as Effect from "effect/Effect"
import * as Layer from "effect/Layer"
```

## Basic Test Structure

```typescript
describe("MyService", () => {
  // Build test layer once
  const PlatformLive = Layer.mergeAll(NodeFileSystem.layer, NodePath.layer)
  const TestLive = MyService.Live.pipe(Layer.provideMerge(PlatformLive))

  describe("methodName", () => {
    it.effect("should do expected thing", () =>
      Effect.gen(function* () {
        const service = yield* MyService
        const result = yield* service.methodName(input)
        expect(result).toBe(expected)
      }).pipe(Effect.provide(TestLive))
    )
  })
})
```

## Testing Errors

```typescript
it.effect("should error on invalid input", () =>
  Effect.gen(function* () {
    const service = yield* MyService

    // Effect.flip swaps success/error channels
    const error = yield* service.methodName(badInput).pipe(Effect.flip)

    expect(error._tag).toBe("MyError")
    expect((error as MyError).reason).toBe("Invalid")
  }).pipe(Effect.provide(TestLive))
)
```

## Temp Directory Helper

```typescript
const withTempDir = <A, E>(
  body: (tempDir: string) => Effect.Effect<A, E, FileSystem | Path | MyService>
) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const tempDir = yield* fs.makeTempDirectory()

    return yield* Effect.acquireUseRelease(
      Effect.succeed(tempDir),
      body,
      (dir) => fs.remove(dir, { recursive: true }).pipe(
        Effect.orElseSucceed(() => undefined)
      )
    )
  })

// Usage
it.effect("should work with files", () =>
  withTempDir((tempDir) =>
    Effect.gen(function* () {
      const service = yield* MyService
      const path = yield* Path.Path
      const filePath = path.join(tempDir, "test.txt")
      // ... test with file
    })
  ).pipe(Effect.provide(TestLive))
)
```

## TDD Workflow (Strict)

```
1. Write test file first (Module.test.ts)
   - Import from implementation (will error - expected)
   - Define API surface via test cases
   - Run: "module not found" error confirms test-first

2. Create minimal implementation
   - Export types and service tags
   - Typecheck passes, tests fail

3. Implement to pass tests
   - One test at a time
   - Red → Green → Refactor
   - Run tests frequently

4. Verify ALL tests pass before moving on
```

## Test File Template

```typescript
/**
 * @module test/MyModule
 * TDD tests for MyModule
 */

import { describe, it } from "@effect/vitest"
import * as Effect from "effect/Effect"
import * as Chunk from "effect/Chunk"
import * as Layer from "effect/Layer"
import { expect } from "vitest"
import { NodeFileSystem, NodePath } from "@effect/platform-node"
import * as FileSystem from "@effect/platform/FileSystem"
import * as Path from "@effect/platform/Path"

import { MyService, MyError } from "../../src/MyModule.js"

// Build layers properly: MyService.Live depends on Platform
const PlatformLive = Layer.mergeAll(NodeFileSystem.layer, NodePath.layer)
const TestLive = MyService.Live.pipe(Layer.provideMerge(PlatformLive))

// Helper for tests needing temp directories
const withTempDir = <A, E>(
  body: (tempDir: string) => Effect.Effect<A, E, FileSystem.FileSystem | Path.Path | MyService>
) =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    const tempDir = yield* fs.makeTempDirectory()
    return yield* Effect.acquireUseRelease(
      Effect.succeed(tempDir),
      body,
      (dir) => fs.remove(dir, { recursive: true }).pipe(Effect.orElseSucceed(() => undefined))
    )
  })

describe("MyModule", () => {
  describe("load", () => {
    it.effect("should load valid data", () =>
      withTempDir((tempDir) =>
        Effect.gen(function* () {
          const service = yield* MyService
          const fs = yield* FileSystem.FileSystem
          const path = yield* Path.Path

          // Setup
          const filePath = path.join(tempDir, "test.txt")
          yield* fs.writeFileString(filePath, "content")

          // Test
          const result = yield* service.load(filePath)
          expect(result).toBe("content")
        })
      ).pipe(Effect.provide(TestLive))
    )

    it.effect("should error when file not found", () =>
      withTempDir((tempDir) =>
        Effect.gen(function* () {
          const service = yield* MyService
          const path = yield* Path.Path

          const filePath = path.join(tempDir, "nonexistent.txt")
          const error = yield* service.load(filePath).pipe(Effect.flip)

          expect(error._tag).toBe("MyError")
          expect((error as MyError).reason).toBe("NotFound")
        })
      ).pipe(Effect.provide(TestLive))
    )
  })
})
```

## Concurrent Test Safety

Effect tests are fiber-safe. For concurrent operations:

```typescript
it.effect("should handle concurrent access", () =>
  Effect.gen(function* () {
    const store = yield* makeStore({ initial: 0 })

    // Run 100 increments concurrently
    yield* Effect.all(
      Array.from({ length: 100 }, () => store.increment),
      { concurrency: "unbounded" }
    )

    const state = yield* store.getState
    expect(state.count).toBe(100)
  })
)
```

## Avoiding Common Test Issues

**Don't use try/catch in Effect.gen:**
```typescript
// WRONG
it.effect("...", () =>
  Effect.gen(function* () {
    try {
      yield* service.doThing()
    } catch (e) {
      // This won't catch Effect failures!
    }
  })
)

// CORRECT
it.effect("...", () =>
  Effect.gen(function* () {
    const result = yield* service.doThing().pipe(Effect.either)
    if (result._tag === "Left") {
      // Handle error
    }
  })
)
```

**Layer composition for tests:**
```typescript
// WRONG - deps not satisfied
const TestLive = Layer.mergeAll(NodeFileSystem.layer, MyService.Live)

// CORRECT - deps satisfied via provideMerge
const TestLive = MyService.Live.pipe(Layer.provideMerge(NodeFileSystem.layer))
```

## Process Spawning Tests (Effect Command)

Use `@effect/platform`'s Command service instead of raw `child_process.spawn`:

```typescript
import * as Command from "@effect/platform/Command"
import * as Stream from "effect/Stream"
import * as Chunk from "effect/Chunk"
import { NodeContext } from "@effect/platform-node"

const runCliWithInput = (cliPath: string, args: string[], input: string) =>
  Effect.gen(function* () {
    const cmd = Command.make("npx", "tsx", cliPath, ...args)
    const proc = yield* Command.start(cmd)

    // Write to stdin
    if (input.length > 0) {
      yield* Stream.make(new TextEncoder().encode(input)).pipe(
        Stream.run(proc.stdin)
      )
    } else {
      yield* Stream.empty.pipe(Stream.run(proc.stdin))
    }

    // Read stdout
    const outputChunk = yield* proc.stdout.pipe(
      Stream.decodeText(),
      Stream.runCollect
    )
    const output = Chunk.toReadonlyArray(outputChunk).join("")

    // Wait for exit
    const exitCode = yield* proc.exitCode

    return { exitCode, output }
  }).pipe(Effect.scoped)  // Auto-cleanup

// Usage
it.effect("exits 0 on success", () =>
  Effect.gen(function* () {
    const { exitCode } = yield* runCliWithInput(
      "./src/bin.ts",
      ["--flag"],
      JSON.stringify({ data: "test" }) + "\n"
    )
    expect(exitCode).toBe(0)
  }).pipe(Effect.provide(NodeContext.layer))
, { timeout: 30000 })  // Process tests need longer timeout
```

**Why Effect Command over child_process.spawn:**
- Scoped cleanup (process killed on scope close)
- Stream-based stdin/stdout
- Effect error handling
- No manual timeout/cleanup logic

## Test Isolation with FiberRef

Avoid mutating `process.env` in parallel tests - use FiberRef:

```typescript
import * as FiberRef from "effect/FiberRef"

// In your module
export const ConfigOverride: FiberRef.FiberRef<string | undefined> =
  FiberRef.unsafeMake<string | undefined>(undefined)

const getConfig = Effect.gen(function* () {
  const override = yield* FiberRef.get(ConfigOverride)
  if (override !== undefined) return override
  return process.env.MY_CONFIG ?? "/default/path"
})

// In tests - fiber-local, safe for parallel execution
it.effect("works with custom config", () =>
  Effect.gen(function* () {
    const result = yield* myEffect
    expect(result).toBe(expected)
  }).pipe(
    Effect.locally(ConfigOverride, "/test/path"),  // Scoped to this fiber
    Effect.provide(TestLive)
  )
)
```

**Why FiberRef over process.env mutation:**
- Fiber-local (parallel test safe)
- Auto-cleanup (no finally block needed)
- Type-safe

## Test Isolation with Service Override Pattern

For file paths or resources that shouldn't touch real files during tests:

```typescript
// 1. Define override service in production module
export class TokenPathOverride extends Context.Tag("app/TokenPathOverride")<
  TokenPathOverride,
  { readonly path: string }
>() {}

// 2. Use Effect.serviceOption to check for override
export const getTokenPath = Effect.gen(function* () {
  const override = yield* Effect.serviceOption(TokenPathOverride)
  if (override._tag === "Some") return override.value.path
  return getDefaultPath()  // Production default
})

// 3. Create helper layer for tests
export const TestPathLayer = (tempDir: string) =>
  Layer.succeed(TokenPathOverride, { path: `${tempDir}/auth.json` })

// 4. In test file - create temp dir in beforeAll, provide override
let tempDir: string
let testLayer: ReturnType<typeof createTestLayer>

function createTestLayer(dir: string) {
  return Layer.merge(
    TestPathLayer(dir),
    NodeFileSystem.layer
  )
}

beforeAll(async () => {
  const setup = Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    return yield* fs.makeTempDirectory({ prefix: "test-" })
  }).pipe(Effect.provide(NodeFileSystem.layer))

  tempDir = await Effect.runPromise(setup)
  testLayer = createTestLayer(tempDir)
})

afterAll(async () => {
  if (tempDir) {
    const cleanup = Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem
      yield* fs.remove(tempDir, { recursive: true })
    }).pipe(Effect.provide(NodeFileSystem.layer))
    await Effect.runPromise(cleanup).catch(() => {})
  }
})
```

**Key patterns:**
- `Effect.serviceOption` returns `Option<Service>`, no error if missing
- `ReturnType<typeof fn>` for inferred layer types (avoids complex annotations)
- `Layer.merge` not `Layer.mergeAll` for combining with path override
- Production code uses default path when override not provided

**Why Service Override over FiberRef:**
- Cleaner for path-based resources
- Works with existing Layer patterns
- More explicit dependency injection
