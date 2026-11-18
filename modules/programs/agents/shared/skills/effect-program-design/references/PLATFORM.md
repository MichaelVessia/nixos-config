# Effect v4 platform services (application code)

Verify APIs against the project's installed Effect v4 declarations. Platform-neutral contracts live in `effect`
modules, such as `effect/FileSystem` and `effect/http/HttpClient`; runtime implementations live in packages such as
`@effect/platform-node`.

## Non-negotiable boundary

**Application/domain/service code depends on Effect services. The executable edge supplies implementations.**

Do not import `node:fs`, `node:path`, `node:crypto`, `node:child_process`, `node:http`, `node:net`, `ws`, raw
`WebSocket`, `ioredis`, or worker-thread APIs in application code when an Effect service exists. Do not hide a
Node API in `Effect.tryPromise`; use the existing service so dependencies, errors, interruption, scopes, and tests
remain explicit. A runtime adapter may use a native constructor only to build the corresponding Effect layer.

| Need                      | Application contract                         | Import                        |
| ------------------------- | -------------------------------------------- | ----------------------------- |
| Files/directories         | `FileSystem.FileSystem`                      | `effect/FileSystem`           |
| Paths                     | `Path.Path`                                  | `effect/Path`                 |
| Secure random/UUID/digest | `SecureRandom`, `Digest`, and other families | `effect/crypto/*`             |
| Interactive terminal      | `Terminal.Terminal`                          | `effect/Terminal`             |
| HTTP client/server        | `HttpClient`, `HttpRouter`, `HttpServer`     | `effect/http/*`               |
| Child process             | `ChildProcess`, `ChildProcessSpawner`        | `effect/process/*`            |
| TCP/Unix/WebSocket        | `Socket.Socket`, `SocketServer.SocketServer` | `effect/socket/*`             |
| Redis                     | `Redis.Redis`                                | `effect/persistence/Redis`    |
| Workers                   | `Worker` / worker RPC abstractions           | `effect/workers/*`            |
| Streaming data            | `Stream`, `Sink`, `Channel`                  | `effect/Stream`, ...          |

Also use `Config` rather than `process.env`, `Effect.log`/`Console` rather than `console.*`, and the Effect CLI
abstractions rather than reading `process.argv` directly.

## Core services

### FileSystem and Path

`FileSystem` returns typed `PlatformError`s and includes whole-file operations, metadata, directories, watching,
backpressured `stream`/`sink`, and scoped file/temp resources. `Path` handles OS-specific separators and file URLs.
Never concatenate path segments manually.

```ts
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Path from "effect/Path";

export const readSettings = Effect.gen(function* () {
  const fs = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const file = path.join("config", "settings.json");
  return yield* fs.readFileString(file);
});
// Effect<string, PlatformError, FileSystem | Path>
```

Prefer `fs.stream(path)` for large input and `fs.sink(path)` for large output. `fs.open`,
`makeTempFileScoped`, and `makeTempDirectoryScoped` require `Scope`; close the scope with `Effect.scoped` at the
owner, not inside a helper that returns the resource.

### Crypto

Effect 4.1 removed `effect/Crypto`. Use the family services in `effect/crypto/*`, such as `SecureRandom` for random
values and UUIDs and `Digest` for hashes. See `CRYPTO.md`. Do not use SHA-1 for new security-sensitive designs.

The service is intentionally not a complete replacement for every host cryptography primitive. If the required
algorithm is absent, isolate native/library crypto in a small adapter service and keep it out of domain code.

### Terminal

Use `Terminal.Terminal` for TTY input/output (`display`, `readLine`, dimensions and key input), and model
`Terminal.QuitError` where user cancellation can occur. Use structured Effect logging for logs; terminal display is
for the interactive UI.

```ts
import * as Effect from "effect/Effect";
import * as Terminal from "effect/Terminal";

export const askName = Effect.gen(function* () {
  const terminal = yield* Terminal.Terminal;
  yield* terminal.display("Name: ");
  return yield* terminal.readLine;
});
```

## HTTP

Outgoing requests depend on `HttpClient.HttpClient`, never directly on `fetch`, Axios, Undici, or Node agents.
Build immutable requests with `HttpClientRequest`; decode untrusted response bodies with `Schema` at the boundary.
Client transport errors are typed HTTP errors and should be captured, then narrowed to domain errors by the owning
service.

```ts
import * as Effect from "effect/Effect";
import * as HttpClient from "effect/http/HttpClient";
import * as HttpClientResponse from "effect/http/HttpClientResponse";
import * as Schema from "effect/Schema";

const User = Schema.Struct({ id: Schema.String, name: Schema.String });

export const getUser = Effect.fn("users.getUser")(function* (id: string) {
  const client = yield* HttpClient.HttpClient;
  const response = yield* client.get(`https://example.test/users/${encodeURIComponent(id)}`);
  return yield* HttpClientResponse.schemaBodyJson(User)(response);
});
```

Servers are expressed with `HttpRouter`/`HttpServer` (or `effect/http-api` for schema-first APIs). Route
handlers remain platform-neutral; only the executable supplies a Node/Bun/web-handler server layer. Long-running
server layers are started with `Layer.launch`.

## Child processes

Use immutable `ChildProcess` descriptions plus the `ChildProcessSpawner` service, not `exec`, `spawn`, or shell
strings. Argument arrays avoid shell quoting and injection. `string`/`lines` collect bounded output; `spawn` gives a
scoped handle for streaming or interaction.

```ts
import * as Effect from "effect/Effect";
import * as ChildProcess from "effect/process/ChildProcess";
import * as ChildProcessSpawner from "effect/process/ChildProcessSpawner";
import * as Str from "effect/String";

export const gitHead = Effect.gen(function* () {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
  const output = yield* spawner.string(ChildProcess.make("git", ["rev-parse", "HEAD"]));
  return Str.trim(output);
});
```

`spawner.spawn(command)` requires `Scope`. Consume `handle.stdout`, `stderr`, or `all` as Effect streams and inspect
`handle.exitCode`; do not forget non-zero exit handling. Use `ChildProcess.pipeTo` for pipelines.

## Sockets and WebSocket

Use `Socket.Socket` for bidirectional bytes/text and `SocketServer.SocketServer` for accepted connections. This is
the application-facing contract for TCP, Unix sockets, and WebSocket-backed transports. Do not instantiate raw
`WebSocket`, `net.Socket`, or `ws` in application code.

```ts
import * as Effect from "effect/Effect";
import * as Socket from "effect/socket/Socket";

export const session = Effect.gen(function* () {
  const socket = yield* Socket.Socket;
  const pull = yield* Socket.readerString(socket); // opens the connection; acquire it before writing
  const writer = yield* socket.writer; // scoped acquisition
  yield* writer.write("hello");
  const messages = yield* pull;
  yield* Effect.logDebug("socket messages", messages);
}).pipe(Effect.scoped);
```

`socket.writer` and the reader are scoped. Reading fails with typed `SocketError`. Effect 4.1 sockets never classify
closes: every close, whatever its code, fails the reader with a `SocketError` that wraps `SocketCloseError`. Handle the
close codes your protocol treats as normal where you read. Prefer the socket `Channel` adapters when implementing a
protocol with bidirectional backpressure.

## Redis

Application code yields the neutral `Redis.Redis` service and calls `send` or a typed `Redis.script`; it must not
yield `NodeRedis`, expose an `ioredis` client, or construct connections.

```ts
import * as Effect from "effect/Effect";
import * as Redis from "effect/persistence/Redis";
import * as Schema from "effect/Schema";

export const readLease = Effect.fn("leases.read")(function* (key: string) {
  const redis = yield* Redis.Redis;
  const reply = yield* redis.send("GET", key);
  return yield* Schema.decodeUnknownEffect(Schema.OptionFromNullOr(Schema.String))(reply);
});
```

For persisted Effect request results, prefer the higher-level `Persistence` layers over hand-written Redis key
management. Map `RedisError` to the owning module's domain error at that module boundary.

## Workers

Use `effect/workers` for worker lifecycle, messaging, interruption, and typed worker errors.
Application code should depend on the worker abstraction or, preferably, a domain service implemented with it.
The platform edge supplies `WorkerPlatform`/`Spawner`; the worker entry supplies `WorkerRunnerPlatform`. Raw
`Worker`, `worker_threads`, `postMessage`, and message listeners belong only in those runtime adapters.

Worker `run` loops own scoped platform resources. Launch handlers under the application scope and let interruption
and finalizers stop them; never create an untracked worker globally.

## Scopes and ownership

- If an API's environment includes `Scope`, it acquired a resource. Keep the scope open for exactly the resource's
  useful lifetime with `Effect.scoped`, a scoped `Layer`, or an enclosing request/application scope.
- Use `Effect.acquireRelease` for custom adapters. Register release immediately after acquisition.
- Use `Effect.forkScoped` for background fibers owned by a layer/request. Avoid floating promises and unscoped
  fibers.
- Do not call `Effect.scoped` too early and return a file, process handle, socket writer, worker, or stream whose
  resource has already been finalized.

## Errors and tests

Platform operations expose typed errors (`PlatformError`, HTTP errors, `SocketError`, `RedisError`, worker/process
errors). Keep them in the error channel, capture them before narrowing, and map them to the service's small public
error vocabulary. Do not `orDie`, throw, or erase them as `unknown` merely to simplify a signature.

Test application code by replacing the **neutral service tag**, not by mocking Node modules:

- `FileSystem.layerNoop({...})` / `FileSystem.makeNoop({...})` for focused file tests.
- `Layer.succeed(Path.Path, ...)`, `Layer.mock` of the required `effect/crypto/*` family service (see `CRYPTO.md`),
  or `Layer.succeed(Terminal.Terminal, Terminal.make(...))` for deterministic fakes.
- A fake `HttpClient`, loopback HTTP layer, recording Redis service, or domain-level worker/socket fake for external
  boundaries.
- Use scoped Effect tests whenever the subject acquires a resource; finalization is part of the assertion.

## Stability warning

Effect 4.1 marks the platform services (`FileSystem`, `Path`, `Terminal`, `Stdio`, and the `effect/crypto/*`
families), HTTP, HTTP API, process, socket, persistence, Redis, CLI, and workers as unstable, as are
`@effect/platform-node` and `@effect/vitest`. These APIs may break in a minor update. The `unstableApiUsage` diagnostic rejects them unless the consumer lists each module in
`allowedUnstableApis`. A re-exported module is identified by its source path, so `NodeCrypto` from
`@effect/platform-node` also needs `@effect/platform-node-shared/NodeCrypto`. Pin all Effect ecosystem packages to the same version, inspect the
installed source before copying examples, and isolate unstable APIs behind deep domain services. Do not copy v3
imports (`@effect/platform/*`) into v4 code: the neutral v4 modules moved into `effect`.
