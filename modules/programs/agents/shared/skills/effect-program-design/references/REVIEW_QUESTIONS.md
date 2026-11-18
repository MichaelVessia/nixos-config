# Review Questions

Ask these questions about each changed file during review. Each one targets a design defect that a syntax rule
cannot see. A yes is a finding. The note after each question sets its scope.

## Source files

### Single use abstraction

Does this file declare a non-exported type, interface, schema fragment, shared-fields object spread
into other objects or schemas, or helper function whose only job is to regroup, rename, or forward
fields or arguments, so that writing its contents inline where it is used would be at least as
clear?

Ignore exported declarations, declarations that contain real logic such as branching, validation,
decoding, error mapping, or I/O, and names for a domain concept that is also used on its own as a
parameter, return, or stored type.

### Error as value

Does any function in this file report a failure as a successful value, for example by returning or
succeeding with { ok: false }, an object with an error or errors field, an Either, Result, or Exit,
an Error instance, or null, undefined, or Option.none() meaning that an operation failed, instead of
failing in the Effect error channel?

Ignore absence that is a normal domain outcome, such as a lookup that found nothing; local branching
on Effect.result or Effect.either that then re-fails or handles each case; aggregates that
intentionally collect per-item successes and failures as data; and protocol encoders that serialize
an error into a wire response.

### Shallow service

Does this file define an Effect service (a Context.Service class, its make effect, or the layer
implementing it) with a public operation that only calls one method on one dependency and returns
that result unchanged, or a public operation whose input or output types include an HTTP or SDK
client, a database row or query-builder type, a connection, a token, or a credential?

Ignore non-exported adapter helpers, and operations that add validation, authorization, decoding,
mapping to domain types, error narrowing, caching, retries, or orchestration of several calls;
adding only a span or a log does not make an operation deep.

### Swallow without capture

Does this file turn an Effect failure into success, using catchTag, catchTags, catch, catchAll,
catchCause, orElse, orElseSucceed, ignore, or a similar recovery, by producing void, a default, or a
fallback value, without logging or reporting that error either inside the handler or in an earlier
tapError in the same pipeline?

Ignore recovery from expected domain outcomes such as NotFound, AlreadyExists, or a validation
failure, and handlers that fail again with another error.

### Unbounded retry

Does this file call Effect.retry, Stream.retry, Effect.retryOrElse, or a similar retry operator with
a policy that has no bound on attempts or elapsed time (for example a bare Schedule.exponential or
Schedule.spaced with no take, recurs, times, or upTo), or that retries every error with no while or
until predicate and no earlier narrowing of the error channel to retryable failures?

Ignore repeat of a successful pass, and retry policies that are bounded by attempts or elapsed time
and only see retryable errors.

### Network call in transaction

Does this file run a database transaction (withTransaction, db.transaction, sql.withTransaction, or
a similar transaction wrapper) whose body makes an HTTP, SDK, or model-provider call, publishes or
sends a message, or sleeps or retries with backoff?

Ignore transaction bodies that only read and write the database, and external calls made before the
transaction starts or after it commits.

### Read then write race

FOR UPDATE, or a unique-claim check on the affected-row count?

Ignore reads used only for a response when the write does not depend on them. Does this file read a
database row's state or existence and then, in a separate statement, conditionally insert or update
that same row based on what it read, without a conditional update guarded on the expected prior
state, an upsert or onConflict clause, a row lock such as SELECT ...

### Unbounded fanout

Does this file run Effect.forEach, Effect.all, Stream.mapEffect, or a similar operator over a
collection whose size is only known at runtime, where each item does I/O, with concurrency set to
"unbounded" or to a value derived from the collection's length?

Ignore fixed literal tuples or records of effects, calls with a fixed numeric concurrency, and calls
that omit concurrency and therefore run sequentially.

### Decode after status

Does this file decode an HTTP response body into a success schema or parse it as JSON without first
checking or classifying the response status, or read the same response body more than once?

Ignore responses already checked with filterStatusOk or a status match, responses from a client
piped through filterStatusOk, and decoding of a separate error schema only for non-success statuses.

### Cache in method

Does this file create a cache or memo, such as Cache.make, Cache.makeWith, Effect.cached,
Effect.cachedWithTTL, or a Map used as a memo, inside a function or operation that runs on every
call, or hand-build a TTL or in-flight cache from a Map plus timestamps, timers, or stored promises?

Ignore caches constructed once while building a layer, a service make, or a module-level value and
then shared.

## Test files

Ask this question about test files only. Skip the source questions for them.

### Test cannot fail

Does this file contain a test case (it, test, it.effect, it.live, it.prop, or a similar test
registration) that would still pass if the behavior named in its title were broken or removed?

Count a test that has no assertions, that asserts only on values the test itself constructed, that
asserts a mock or fake returns what the test configured it to return, that asserts only facts the
type system already guarantees, or whose only assertions run inside a loop over a list that may be
empty; do not count tests whose assertions observe the output, error, or end state produced by the
code under test.
