# Services and Layers

Services declare capabilities; layers construct implementations. The environment is the dependency graph.

## Service shape

- Make operations domain-shaped and Effect-returning.
- Keep success, typed error, and requirements visible in each operation type.
- Use named input objects and narrow per-operation errors.
- Yield dependencies from the environment rather than accepting service instances as parameters.
- Load configuration with `Config` in the implementing layer. Keep secrets `Redacted` until the adapter edge.

Small modules may collocate tag, shape, errors, and live layer. Larger services and external adapters should split the
public tag, live wiring, errors, schemas, persistence, and transport concerns. Collocation is a complexity decision,
not permission to tangle public contracts with implementation details.

## Live implementation: `make` and `static layer`

Give each service its constructor as a `make` effect on the class, and build its layer from that `make` as
`public static readonly layer`. `make` yields every dependency from the environment. No function takes a service instance as
a parameter, and there are no separate `WidgetServiceLive` constants or `makeWidgetServiceWith(provider)` variants.

```ts
export class WidgetService extends Context.Service<
  WidgetService,
  {
    readonly list: (input: ListWidgetsInput) => Effect.Effect<ReadonlyArray<Widget>, WidgetError>;
  }
>()("@app/widgets/WidgetService", {
  make: Effect.gen(function* () {
    const provider = yield* WidgetProvider; // dependencies come from yield*, never from parameters

    return {
      list: Effect.fn("widgetService.list")(function* (input: ListWidgetsInput) {
        const widgets = yield* provider.fetch({ organizationId: input.organizationId });
        return Arr.filter(widgets, (widget) => !widget.archived);
      }),
    };
  }),
}) {
  public static readonly layer = Layer.effect(this, this.make);
}

// Runtime composition provides it once:
const AppLayer = WidgetService.layer.pipe(Layer.provide(WidgetProvider.layer));
```

- `make` yields each dependency once and the operations use the yielded value directly. Never capture
  `Effect.context` to re-provide it later, and never re-provide a yielded service with `Effect.provide` or
  `Effect.provideService`; yield each service with `yield*` instead. An effect that runs outside the caller's
  fiber is the exception; see [Deferred effects and library callbacks](#deferred-effects-and-library-callbacks).
- `WidgetService.make` is the constructor. Hosts that build the service themselves `yield*` it. An example is a
  Durable Object that constructs per-instance services. Tests can do the same, providing the dependencies.
- `WidgetService.layer` is what runtime composition provides. Effect v4 has no `Layer.scoped`: `Layer.effect` runs
  `make` in the layer's scope, so resources acquired with `Effect.acquireRelease` in `make` release with the layer.
- A variant layer is derived from `layer`, not from a second constructor. For example,
  `public static readonly layerSelfBinding = WidgetService.layer.pipe(Layer.provide(selfBindingHttpClient))`.

When construction needs plain configuration, such as a batch size or concurrency limit, make both static functions of
that configuration. Their arguments are only plain values, never services, layers, contexts, or handler functions with
their own requirements. Behavior that differs per host is a service the host provides:

```ts
// The handlers are their own service. Its dependencies are yielded in its own make.
export class MailboxProcessors extends Context.Service<
  MailboxProcessors,
  {
    readonly deliver: (input: { readonly message: MailboxMessage }) => Effect.Effect<void, DeliveryError>;
  }
>()("@app/delivery/MailboxProcessors", {
  make: Effect.gen(function* () {
    const webhooks = yield* WebhookClient;
    return {
      deliver: ({ message }) =>
        webhooks.post({ message }).pipe(Effect.withSpan("mailboxProcessors.deliver")),
    };
  }),
}) {
  public static readonly layer = Layer.effect(this, this.make);
}

export class MailboxProcessing extends Context.Service<
  MailboxProcessing,
  { readonly processReady: Effect.Effect<void, MailboxUnavailable | DeliveryError> }
>()("@app/delivery/MailboxProcessing") {
  public static readonly make = (options: MailboxProcessingOptions) =>
    Effect.gen(function* () {
      const backend = yield* MailboxProcessingBackend;
      const processors = yield* MailboxProcessors;

      return MailboxProcessing.of({
        processReady: Effect.gen(function* () {
          const ready = yield* backend.claimReady({ limit: options.batchSize });
          yield* Effect.forEach(
            ready,
            (message) =>
              processors
                .deliver({ message })
                .pipe(Effect.andThen(backend.markDelivered({ messageId: message.id }))),
            { concurrency: options.concurrency, discard: true },
          );
        }).pipe(Effect.withSpan("mailboxProcessing.processReady")),
      });
    });

  public static readonly layer = (options: MailboxProcessingOptions) =>
    Layer.effect(MailboxProcessing, MailboxProcessing.make(options));
}

// Runtime composition:
// MailboxProcessing.layer(options).pipe(Layer.provide(MailboxProcessors.layer), Layer.provide(...))
```

`make` yields the backend and the processors and uses them directly, so no requirement is left open to capture. A host
that builds the service itself, such as a Durable Object whose alarm handlers depend on the instance, runs
`MailboxProcessing.make(options)` with its own handlers provided as a value:
`Effect.provideService(MailboxProcessors, MailboxProcessors.of({ deliver: ... }))`. That provides a newly built
implementation, which is different from re-providing a service it already yielded.

Prefer leaving dependencies in a substantial operation's `R` channel and satisfying them at runtime composition.
Capturing a yielded dependency is reasonable when an acquired resource or configured client is genuinely layer-local
(e.g. an effect needs a runtime-constructed httpClient with credentials provided for a given organization that were looked up at runtime).
Do not manufacture production `Base` layers solely to make testing possible; keep the real dependency seam visible.

Layers that depend on other services should yield those services. Business services should not construct dependency
layers. Runtime composition owns assembly. A justified exception is a dynamically credentialed client whose lifetime
or configuration can only be known during an operation; isolate that adapter behavior and keep it typed.

## Deferred effects and library callbacks

Some effects run later, outside the fiber of the operation that uses them. Their requirements cannot flow through
`R`, so `make` closes them over its services. The form depends on who runs the effect.

A non-Effect library that calls back, such as a driver's password callback or an event listener, has no fiber to
inherit services from. Capture the context those effects need and run each one with
`Effect.runPromiseWith(context)`, `Effect.runForkWith(context)`, or `Effect.runCallbackWith(context)`. Never call
`Effect.runPromise` or `Effect.runFork` there.

```ts
make: Effect.gen(function* () {
  const context = yield* Effect.context<Credentials | Region>();
  return {
    driver: new Driver({ password: () => Effect.runPromiseWith(context)(signToken(endpoint)) }),
  };
}),
```

An Effect value that a library or a cache runs later and whose type requires no services is different. Examples are
an `@effect/sql-pg` `password` effect, an `Effect.cachedWithTTL` SDK call, and an operation that calls an SDK
function whose requirements are services. Yield each service and close the effect over it with
`Effect.provideService` inside a function:

```ts
make: Effect.gen(function* () {
  const credentials = yield* Credentials;
  const region = yield* Region;
  const withAws = <A, E>(effect: Effect.Effect<A, E, Credentials | Region>): Effect.Effect<A, E> =>
    effect.pipe(Effect.provideService(Credentials, credentials), Effect.provideService(Region, region));
  const caller = yield* withAws(describeCaller).pipe(Effect.cachedWithTTL(Duration.hours(1)));
  return {
    password: withAws(signToken(endpoint)).pipe(Effect.withSpan("database.signToken")),
    caller: caller.pipe(Effect.withSpan("aws.describeCaller")),
  };
}),
```

Do not provide a captured `Effect.context` to an Effect value. `Effect.provide(context)` replaces the services of the
fiber that runs the effect, so its spans nest under the span that built the service, not under the caller's span.
`Effect.provideService` replaces only the service it names. This package's `flo-effect/prefer-yield-service` rule
rejects a captured context provided back, and `flo/no-reprovide-ambient-service` rejects `Effect.provideService` in
the function that yielded the service.

## Independently testable operation effects

Substantial effects remain first-class even when a service is small. Define them outside a large layer constructor so
their `Effect<A, E, R>` type documents requirements and tests can provide only the needed layers. They may remain in
the same file or be extracted by concern. Do not extract trivial wrappers merely to satisfy a file convention.

Both forms below are valid stable operation boundaries. This package's `prefer-effect-fn-over-arrow-gen` rule rejects
a named arrow that returns `Effect.gen`, so give a generator body `Effect.fn`. End a pipeline with `Effect.withSpan`.

```ts
const getStatus = Effect.fn("widget.getStatus")(function* (input: GetStatusInput) {
  yield* Effect.annotateCurrentSpan({ organization_id: input.organizationId });
  // ...
});

const refreshStatus = (input: GetStatusInput) =>
  provider.refresh({ organizationId: input.organizationId }).pipe(
    Effect.withSpan("widget.refreshStatus", { attributes: { organization_id: input.organizationId } }),
  );
```

This package's `flo-effect/require-operation-span` rule checks each value in the object that `make` returns that is
evidently an Effect or a Stream: an `Effect.*` or `Stream.*` call, a pipe with an `Effect.*` or `Stream.*` step, or a
function that returns one. It follows a name to its single declaration in the file. A named value must end its pipe
with the span. Bind an operation that another operation also calls in `make`, and return it by name. When an operation
is extracted outside `make`, define it with `Effect.fnUntraced` and add the span where `make` returns it:
`getStatus: (input) => getStatusEffect(input).pipe(Effect.withSpan("widget.getStatus"))`. A call of a traced
operation, such as `tick().pipe(Effect.ignore)`, starts no span of its own, so the rule rejects it. The rule cannot see
a call of a helper that returns an effect, so give such an operation its span without a prompt from the rule. End a
Stream operation with `Stream.withSpan("widget.changes")`.

Use safe span attributes. Never annotate credentials, tokens, request bodies containing secrets, or unrestricted raw
provider responses.

## Test-only implementations

All test code lives in the package's `test/` directory, outside `src/`: test files, test layers, fakes, fixtures,
recording services and helpers (shared ones in `test/support/`). Production modules never export `layerTest`,
`layerFake`, `layerMock`, or any fake, and never import from `test/`. The only exception is a fixtures layer in `src/`
that stands in for a feature not built yet, with a doc comment saying what it replaces and when it goes away.

Tests build layers from the production class: the real service through `Service.layer` (or `yield* Service.make`)
with its dependencies provided by `Layer.succeed(Dep, Dep.of({...}))`, `Layer.mock`, or a real test resource.

```ts
// test/support/layers.ts
const WidgetProviderTest = Layer.succeed(
  WidgetProvider,
  WidgetProvider.of({ fetch: () => Effect.succeed([]), remove: () => Effect.die("unexpected remove") }),
);
export const WidgetServiceTest = WidgetService.layer.pipe(Layer.provide(WidgetProviderTest));
```

Do not use module mocks or method spies. If a dependency cannot be replaced by providing a layer, repair the module's
dependency boundary.

## Composition rules

- Assemble complete runtimes at application entry points.
- Provide each service's implementing Layer once when constructing the application's Effect runtime. The implemented
  service is then available through the Effect environment; do not re-provide its Layer inside operations, handlers,
  callbacks, or unrelated implementing Layers.
- Exception: provide an implementing Layer later only when it cannot be constructed during application runtime
  creation because required configuration or resources do not exist yet. Examples include credentials selected for
  the current tenant, request-derived client configuration, or a transport created for a new connection. Provide it
  at the narrowest scope that owns both the required values and its lifetime.
- Keep dependency wiring inside the module that owns it. Never require callers to pass `Context`, `Layer`,
  `ManagedRuntime`, or service instances as ordinary arguments.
- Use `Layer.provide`/`provideMerge` deliberately; avoid invisible global dependencies.
- Acquire resources in `make` with `Effect.acquireRelease`; `Layer.effect` scopes them to the layer.
- Do not call `Effect.runPromise` inside services.
- Do not pass a `Layer` into an operation.
- Do not hide initialization failures with `orDie`; classify, capture, and expose or handle them intentionally.
- A shared `ManagedRuntime` memoizes layers by reference across runtime calls. When a reused layer captures per-request,
  per-session, per-task, or per-tenant configuration or mutable state, wrap the complete dynamic layer subtree in
  `Layer.fresh`.
- Do not freshen intentional application singletons such as database pools and generic HTTP clients. Freshness must
  match the service's intended lifetime.
