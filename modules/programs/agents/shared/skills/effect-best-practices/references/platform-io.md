# Platform I/O, Config, and Error Discipline

## Rule: No Sync Node.js I/O in Effect Code

Effect tracks all side effects. Synchronous Node.js calls (`readFileSync`,
`existsSync`, `writeFileSync`, `mkdirSync`, `readdirSync`, `statSync`,
`symlinkSync`, `execSync`) bypass Effect's runtime, breaking:

- **Testability**: Can't mock with `FileSystem.layerNoop` or service substitution
- **Consistency**: Mix of tracked and untracked I/O
- **Concurrency**: Sync calls block the event loop

### What to Use Instead

| Node.js Sync Call | Effect Platform Replacement |
|-------------------|-----------------------------|
| `existsSync(path)` | `fs.exists(path)` |
| `readFileSync(path, 'utf-8')` | `fs.readFileString(path)` |
| `writeFileSync(path, data, 'utf-8')` | `fs.writeFileString(path, data)` |
| `mkdirSync(path, { recursive: true })` | `fs.makeDirectory(path, { recursive: true })` |
| `readdirSync(path)` | `fs.readDirectory(path)` (returns `string[]`) |
| `statSync(path)` | `fs.stat(path)` (returns `File.Info`, `mtime` is `Option<Date>`) |
| `symlinkSync(target, link)` | `fs.symlink(target, link)` |
| `execSync(cmd)` | Inject a shell runner service or use Effect platform `Command` |

### How to Access FileSystem

```typescript
import { Effect, FileSystem } from 'effect'

// In an Effect.gen context (orchestrator or service method)
const fs = yield* FileSystem.FileSystem

// In a service layer (yield at construction, close over)
export const MyServiceLive = Layer.effect(
  MyService,
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem
    return {
      doThing: Effect.fn('MyService.doThing')(function* () {
        const exists = yield* fs.exists('/some/path')
        // ...
      }),
    }
  }),
)
```

### Providing FileSystem

```typescript
// Production: BunServices or NodeContext provides FileSystem
import { BunServices } from '@effect/platform-bun'
const AppLayer = Layer.mergeAll(BunServices.layer, ServiceLayers)

// Tests: use FileSystem.layerNoop for mocking
const MockFs = FileSystem.layerNoop({
  writeFileString: () => Effect.void,
  makeDirectory: () => Effect.void,
  exists: () => Effect.succeed(true),
})
const TestLayer = Layer.mergeAll(MockService, MockFs)
```

### Detection (grep for violations)

```bash
rg "from 'node:fs'" --type ts
rg "from 'node:child_process'" --type ts
rg "existsSync|readFileSync|writeFileSync|mkdirSync|readdirSync|statSync|symlinkSync" --type ts
rg "execSync" --type ts
```

---

## Rule: Use Config for Tunable Constants

Hardcoded module-level constants that represent operational tunables (timeouts,
concurrency limits, org names, staleness thresholds) should use Effect `Config`
so they're overridable via environment variables without code changes.

### Before (hardcoded)

```typescript
const ORG = 'flocasts'
const CUTOFF_DAYS = 365
const README_CONCURRENCY = 10
```

### After (Config with defaults)

```typescript
import { Config } from 'effect'

const OrgConfig = Config.string('FLOAI_ORG').pipe(Config.withDefault('flocasts'))
const CutoffDaysConfig = Config.number('FLOAI_CUTOFF_DAYS').pipe(Config.withDefault(365))
const ReadmeConcurrencyConfig = Config.number('FLOAI_README_CONCURRENCY').pipe(Config.withDefault(10))

// In the orchestrator
const org = yield* OrgConfig
const cutoffDays = yield* CutoffDaysConfig
```

### Config Patterns

```typescript
// Fallback chain
const editor = Config.string('MY_EDITOR').pipe(
  Config.orElse(() => Config.string('EDITOR')),
  Config.withDefault('nano'),
)

// Optional (returns Option)
const apiKey = Config.redacted('API_KEY').pipe(Config.option)

// Transformed
const timeout = Config.number('TIMEOUT_MS').pipe(
  Config.map(Duration.millis),
  Config.withDefault(Duration.seconds(30)),
)
```

### What NOT to Config-ify

- Internal implementation details (buffer sizes, internal retry counts)
- Values that are truly constant (protocol strings, file extensions)
- Values derived from other config (compute them, don't duplicate)

---

## Rule: No Blanket Error Suppression

Blanket `Effect.catchAll(() => Effect.succeed(fallback))` hides real errors.
Distinguish between expected errors (file not found, 404) and unexpected ones
(auth failures, network timeouts).

### Before (blanket catch)

```typescript
const result = yield* dangerousOp.pipe(
  Effect.catch(() => Effect.succeed(fallback))
)
```

### After (selective catch)

```typescript
// Option 1: Catch specific error tag
const result = yield* dangerousOp.pipe(
  Effect.catchTag('NotFoundError', () => Effect.succeed(fallback))
)

// Option 2: Inspect error content
const result = yield* fetchReadme(repo).pipe(
  Effect.catchTag('GitHubApiError', (e) =>
    e.message.includes('404') || e.message.includes('Not Found')
      ? Effect.succeed('')
      : Effect.fail(e),
  ),
)

// Option 3: Log before fallback (when catch-all is intentional)
const result = yield* dangerousOp.pipe(
  Effect.tapError((e) => Effect.logWarning('Falling back', { error: String(e) })),
  Effect.catchAll(() => Effect.succeed(fallback))
)
```

### When Blanket Catching is OK

- Best-effort operations with explicit `Effect.logWarning` before fallback
- Cleanup/finalizer code where failure shouldn't propagate
- Top-level CLI error boundaries

### When it is NOT OK

- Inside services where errors should propagate to callers
- When different error types need different handling
- When the fallback masks bugs (empty arrays hiding auth failures)
