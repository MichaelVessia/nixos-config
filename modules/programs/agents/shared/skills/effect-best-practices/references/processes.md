# Process & Scope Management in Effect

How to spawn, manage, and kill child processes using @effect/platform.

## Quick Reference

```typescript
import * as Command from "@effect/platform/Command"
import * as CommandExecutor from "@effect/platform/CommandExecutor"
import * as Scope from "effect/Scope"
import * as Exit from "effect/Exit"
```

## The Core Insight

`CommandExecutor.start` returns `Effect<Process, PlatformError, Scope>` - **Process is a scoped resource**.

```typescript
// Process requires Scope because it uses acquireRelease internally:
Effect.acquireRelease(
  spawn,  // acquire: spawn child process
  ([handle, exitCode]) => {
    // release: kill if still running, cleanup orphans
    if (!done) return killProcessGroup(handle, "SIGTERM")
    return cleanupOrphans()
  }
)
```

## Two Lifetime Patterns

### Pattern 1: Automatic (Short-Lived Commands)

Use `Effect.scoped` when process lifetime = effect lifetime:

```typescript
const output = yield* Effect.scoped(
  Effect.gen(function* () {
    const process = yield* executor.start(cmd)
    return yield* streamToString(process.stdout)
  })
)
// Process auto-killed when scope exits
```

### Pattern 2: Manual (Background/Killable Processes)

Use `Scope.make()` + `Scope.extend()` for external control:

```typescript
// Create scope WE control
const scope = yield* Scope.make()

// Start process in OUR scope
const process = yield* executor.start(cmd).pipe(Scope.extend(scope))

// Store handles for later
yield* Ref.update(registry, (m) => HashMap.set(m, id, { process, scope }))

// Fork ONLY the output collection (not the scoped acquisition)
yield* Effect.forkDaemon(collectOutput(process))

// Later, to kill:
yield* process.kill("SIGTERM")
yield* Scope.close(scope, Exit.void)
```

## Fork Types (Critical Distinction)

| Type | Lifetime | Cleanup | Use Case |
|------|----------|---------|----------|
| `fork` | Dies with parent | Automatic | Concurrent work |
| `forkScoped` | Dies with scope | Auto-registered | Server workers |
| `forkDaemon` | Independent | **Manual required** | Background tasks |

```typescript
// forkDaemon needs manual cleanup!
const fiber = yield* Effect.forkDaemon(work)
yield* scope.addFinalizer(() => Fiber.interrupt(fiber))
```

## Process Interface

```typescript
interface Process {
  readonly pid: ProcessId
  readonly exitCode: Effect<ExitCode>      // Waits for completion
  readonly isRunning: Effect<boolean>
  readonly kill: (signal?: Signal) => Effect<void>  // SIGTERM default
  readonly stdout: Stream<Uint8Array>
  readonly stderr: Stream<Uint8Array>
  readonly stdin: Sink<void, Uint8Array>
}
```

## Scope.extend Explained

`Scope.extend(scope)` does two things:
1. Ties resource lifetime to the provided scope
2. **Removes `Scope` from effect requirements** (you've satisfied it)

```typescript
// Before: Effect<Process, E, CommandExecutor | Scope>
const scoped = executor.start(cmd)

// After: Effect<Process, E, CommandExecutor>  (no Scope requirement!)
const extended = scoped.pipe(Scope.extend(myScope))
```

## Scope.close

```typescript
// Normal shutdown
yield* Scope.close(scope, Exit.void)

// Error shutdown (finalizers see the cause)
yield* Scope.close(scope, Exit.failCause(cause))
```

Finalizers run in LIFO order (reverse of registration).

## Common Anti-Pattern

**WRONG: Effect.scoped inside forkDaemon**

```typescript
// BAD: Process trapped inside daemon's scope - unreachable!
yield* Effect.forkDaemon(
  Effect.scoped(
    Effect.gen(function* () {
      const process = yield* executor.start(cmd)  // Can't access this!
      // ...
    })
  )
)
```

**RIGHT: Manual scope, fork only the work**

```typescript
// GOOD: We control the scope, can access process later
const scope = yield* Scope.make()
const process = yield* executor.start(cmd).pipe(Scope.extend(scope))
// Store process + scope...
yield* Effect.forkDaemon(collectOutput(process))  // Fork only collection
```

## Kill Strategy (from Effect platform)

```typescript
const kill = (signal = "SIGTERM") =>
  killProcessGroup(handle, signal).pipe(    // 1. Try killing process group
    Effect.orElse(() => killProcess(handle, signal)),  // 2. Fallback to single process
    Effect.zipRight(Deferred.await(exitCode))  // 3. Wait for exit event
  )
```

- Unix: `process.kill(-pid, signal)` kills entire process group
- Windows: `taskkill /pid {pid} /T /F` kills tree

## Real-World Example: Killable Background Shell

```typescript
interface BackgroundShell {
  readonly id: string
  readonly command: string
  readonly process: Process              // For kill()
  readonly scope: Scope.CloseableScope   // For cleanup
  readonly output: string
  readonly isComplete: boolean
  readonly exitCode?: number
}

// Start background shell
const startBackground = (command: string) =>
  Effect.gen(function* () {
    const executor = yield* CommandExecutor.CommandExecutor
    const shells = yield* ShellRegistry

    const id = `shell-${crypto.randomUUID()}`
    const scope = yield* Scope.make()

    const cmd = Command.make("bash", "-c", command)
    const process = yield* executor.start(cmd).pipe(Scope.extend(scope))

    yield* Ref.update(shells, (m) => HashMap.set(m, id, {
      id, command, process, scope,
      output: "", isComplete: false
    }))

    // Fork output collection
    yield* Effect.forkDaemon(
      Effect.gen(function* () {
        const [stdout, stderr, exit] = yield* Effect.all([
          streamToString(process.stdout),
          streamToString(process.stderr),
          process.exitCode
        ], { concurrency: "unbounded" })

        yield* Ref.update(shells, (m) => HashMap.modify(m, id, (s) => ({
          ...s,
          output: stdout + stderr,
          isComplete: true,
          exitCode: exit
        })))
      }).pipe(Effect.ignore)
    )

    return id
  })

// Kill background shell
const killShell = (id: string) =>
  Effect.gen(function* () {
    const shells = yield* ShellRegistry
    const shell = yield* Ref.get(shells).pipe(
      Effect.map((m) => HashMap.get(m, id)),
      Effect.flatMap(Effect.fromOption)
    )

    if (!shell.isComplete) {
      yield* shell.process.kill("SIGTERM")
    }
    yield* Scope.close(shell.scope, Exit.void)

    return { success: true, status: shell.isComplete ? "already_completed" : "killed" }
  })
```

## References

- Effect platform source: `<effect-repo>/packages/platform-node-shared/src/internal/commandExecutor.ts`
- Scope internals: `<effect-repo>/packages/effect/src/internal/fiberRuntime.ts`
