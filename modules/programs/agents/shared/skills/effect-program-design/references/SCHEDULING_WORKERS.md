# Scheduling, Retry, and Workers (Effect v4)

Use this reference for retry, repeat, polling, background workers, timeouts, and rate-aware backoff. Verify API names
against the project's installed Effect v4 declarations. In Effect 4.1, `Schedule.max([delay, Schedule.recurs(n)])`
bounds a delay schedule; check the installed version before copying examples from another release.

## Choose the primitive

- Retry a typed failure: `Effect.retry(effect, schedule)` or `effect.pipe(Effect.retry(schedule))`.
- Repeat a successful pass: `Effect.repeat(effect, schedule)`. A failure stops repetition unless the pass handles it.
- Run one operation later: `Effect.delay`; model sleeping as behavior with `Effect.sleep`.
- Enforce a real deadline: `Effect.timeout` (interruption must be safe).
- Emit values over time: `Stream.fromSchedule`; otherwise a worker usually needs `Effect.repeat`, not a stream.
- Own a long-lived worker in a layer: `Effect.forkScoped`; scope closure interrupts and joins its lifetime.

The source effect runs once before a retry/repeat schedule advances. `Schedule.recurs(3)` therefore permits three
additional attempts. `Schedule.spaced` waits after a pass completes; `Schedule.fixed` targets a cadence.

## Retry policy: narrow, bounded, idempotent

Retry only a typed, transient error at the narrowest adapter boundary. Never retry all errors merely because they
come from an upstream. Creates and lifecycle transitions require an idempotency key, unique claim, or atomic guard;
do not hold a database transaction open during backoff or a network call. Ask the user when domain retry policy or
retry safety is unclear.

```ts
import * as Effect from "effect/Effect";
import * as Schedule from "effect/Schedule";

const retryTransient = Schedule.max([
  Schedule.exponential("100 millis").pipe(Schedule.jittered),
  Schedule.recurs(4), // at most four retries after the initial attempt
]).pipe(
  Schedule.setInputType<ProviderUnavailableError>(),
  Schedule.tap(({ input, attempt }) =>
    Effect.logWarning("provider.retrying").pipe(
      Effect.annotateLogs({ operation: input.operation, attempt }),
    ),
  ),
);

const call = request(input).pipe(
  // First restrict the channel to the exact retryable tag(s), or design the adapter
  // method so its error channel contains only retryable failures here.
  Effect.retry(retryTransient),
);
```

Add jitter to distributed retries. Keep the final typed failure visible. Use `Effect.retryOrElse` only when the
fallback is truthful; capture the exhausted error before narrowing or swallowing it.

```ts
const resilient = request(input).pipe(
  Effect.retryOrElse(retryTransient, (error) =>
    captureProviderFailure(error, { operation: error.operation }).pipe(
      Effect.andThen(Effect.fail(WidgetUnavailableError.make({ cause: error }))),
    ),
  ),
);
```

Do not retry defects or interruptions. `Effect.retry` naturally operates on the typed error channel. Do not
`catchCause` and turn every cause into a retryable error.

## Polling worker

Handle expected pass errors _inside_ the pass, after capture, so repetition can continue. Leave defects and
interruptions to supervision unless the explicit top-level policy says otherwise.

```ts
const pass: Effect.Effect<void, never, WorkerDeps> = runPass.pipe(
  Effect.tapError((error) => capturePassFailure(error)), // structured log or configured reporter, safe fields
  Effect.catchTags({
    QueueTemporarilyUnavailableError: () => Effect.void,
    ItemLeaseLostError: () => Effect.void,
  }),
);

const worker = pass.pipe(Effect.repeat(Schedule.spaced("1 second")), Effect.asVoid);

export const WorkerLive = Layer.effectDiscard(worker.pipe(Effect.forkScoped));
```

Capture the raw tagged error before converting it to `void` or a smaller public error. A worker declared
`Effect<void, never>` is a promise that all expected failures are observed and deliberately absorbed—not permission
to use `Effect.ignore` without evidence. At a true supervision boundary, `catchCause` may capture non-interruption
causes, but do not swallow interruption during shutdown.

## Batch passes

Use bounded concurrency and isolate an item only when skip/retry-later is the product policy.

```ts
yield* Effect.forEach(
  items,
  (item) =>
    processItem(item).pipe(
      Effect.tapError((error) => captureItemFailure(error, { itemId: item.id })),
      Effect.catchTags({ ItemRejectedError: () => Effect.void }),
    ),
  { concurrency: 5, discard: true },
);
```

Claim work atomically, make repeated handling idempotent, and avoid fetching an unbounded batch. Prefer a bounded
lease/claim protocol over an in-memory "currently processing" set.

## Provider retry delays

If a typed error carries `retryAfterMs`, combine it with backoff using `Schedule.modifyDelay`. In Effect 4.1 its
callback receives one metadata object: `input` is the error, `output` is the schedule's output, and `duration` is
the computed delay.

```ts
import * as Duration from "effect/Duration";
import * as Effect from "effect/Effect";
import * as Schedule from "effect/Schedule";

const policy = Schedule.max([
  Schedule.exponential("200 millis").pipe(Schedule.jittered),
  Schedule.recurs(5),
]).pipe(
  Schedule.setInputType<ProviderRateLimitedError>(),
  Schedule.modifyDelay(({ input, duration }) =>
    Effect.succeed(
      input.retryAfterMs === undefined ? duration : Duration.max(duration, Duration.millis(input.retryAfterMs)),
    ),
  ),
);
```

For HTTP-wide transient classification or proactive rate limiting, also read `HTTP_CLIENTS.md`.

## Tests and observability

- Test timing with `TestClock`; never make unit tests wait in real time.
- Put a span around each public start/stop/run-once method and child spans around I/O, not around every tick helper.
- Log retry attempt, safe operation/ID fields, and terminal exhaustion. Never annotate tokens, URLs containing
  credentials, payloads, or `Redacted.value(secret)`.
- Ensure scoped workers stop when their layer scope closes; no floating `runFork`/promise launched from a layer.
