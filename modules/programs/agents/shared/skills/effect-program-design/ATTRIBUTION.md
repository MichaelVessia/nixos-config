# Attribution

This skill is copied from the `effect-program-design` skill in
[k-mistele/anti-slop](https://github.com/k-mistele/anti-slop/tree/b7c1619b4d51b4815e89ba3700a975a6ec54b8c3/skills/effect-program-design)
at commit `b7c1619b4d51b4815e89ba3700a975a6ec54b8c3`, licensed under the MIT License:

> MIT License
>
> Copyright (c) 2026 Dillon Mulroy
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
> documentation files (the "Software"), to deal in the Software without restriction, including without limitation
> the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of
> the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
> THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
> TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

The upstream skill keeps this notice for its own source:

Parts of this skill's Effect v4 API guidance and progressive-disclosure organization were adapted from
[`kitlangton/skills`](https://github.com/kitlangton/skills), licensed under the MIT License:

> MIT License
>
> Copyright (c) 2026 Kit Langton
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
> documentation files (the "Software"), to deal in the Software without restriction, including without limitation
> the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
> permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of
> the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
> THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
> TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

## Changes in this package

These edits make the examples and guidance match the checks this package enforces and its pinned Effect 4.1.0.
Each TypeScript example was typechecked against Effect 4.1.0 with this package's Effect diagnostics. Examples that use
names their reference does not define were checked with stand-in declarations for those names. The `node:*` imports
in `PLATFORM_NODE.md` need the consumer override that file describes.

- Class members use `public static readonly`, as `typescript/explicit-member-accessibility` requires. `SKILL.md`
  notes that the base preset also requires return types on exported functions.
- Span names use dotted lower camel case, such as `appRegistry.find`, as `effect-fn-span-name` requires.
- Examples import module namespaces, such as `import * as Effect from "effect/Effect"`, instead of value imports from
  the `effect` barrel, which the Effect preset rejects.
- Every typed error uses `Schema.TaggedError`, including internal-only errors. Upstream permits `Data.TaggedError`
  for those. This package rejects it with `no-data-tagged-error` and the `preferSchemaTaggedError` diagnostic.
- A named arrow that returns `Effect.gen` becomes `Effect.fn`, as `prefer-effect-fn-over-arrow-gen` requires. The
  `SERVICES_LAYERS.md` example no longer marks that arrow form as preferred, and `Effect.withSpan` ends a pipeline.
- Test examples assert with `assert` from `@effect/vitest` instead of `expect`, as `no-expect-in-it-effect`
  requires, and use `Effect.tryPromise` instead of the rejected `Effect.promise`. The `it.live` example carries the
  `no-it-live` suppression with its reason.
- Collection guidance names `HashMap` and `HashSet`, because `no-native-collections` rejects `new Map` and `new Set`.
- Native array methods become `effect/Array` calls, as the `preferEffectArray` diagnostic requires. The batching
  example replaces a `for` loop, which `no-imperative-loops` rejects, with `Effect.forEach` and explicit concurrency.
- Records use a same-name type alias instead of an empty interface, which the base preset rejects.
- `effect/unstable/*` imports become their Effect 4.1 paths, such as `effect/http/HttpClient`. The stability notes
  name the `unstableApiUsage` diagnostic and `allowedUnstableApis`.
- Effect 4.1 removed `effect/Crypto`. `PLATFORM.md` points to the `effect/crypto/*` families, and `CRYPTO.md`, written
  for this package, covers them. `PLATFORM_NODE.md` no longer lists crypto in `NodeServices.layer`, and the test
  fakes in `PLATFORM.md` use `Layer.mock` of a family service. `digestHex` is a method of the `Digest` service.
- Config recipes use the Effect 4.1 constructors `Config.String`, `Config.Int`, `Config.URL`, and `Config.Redacted`.
  `Config.mapOrFail` becomes `Config.schema` or `Config.mapEffect`.
- Schedules bound attempts with `Schedule.max` and `Schedule.recurs` instead of `Schedule.take`, log with
  `Schedule.tap` instead of `Schedule.tapInput`, and use the one-argument metadata callback of
  `Schedule.modifyDelay`. The `Effect.retryOrElse` fallback no longer calls the schedule output `attempts`.
- `Option.fromNullable` becomes `Option.fromNullishOr`.
- The socket examples use the Effect 4.1 `Socket` writer and reader. Effect 4.1 has no `closeCodeIsError` option:
  every close fails the reader.
- The Redis example passes node-redis options to `NodeRedis.layerConfig`, because `NodeRedis` wraps the `redis`
  package, not ioredis.
- Schema errors are constructed with `X.make(...)`, as the `newSchemaClass` diagnostic requires. The stream adapter
  error calls `Schema.Defect()` and carries a brand, as `schemaClassMissingBrand` requires.
- Examples satisfy these diagnostics: `preferEffectArray` and `mapMapErrorToMapBoth` (`Arr.map` inside
  `Effect.mapBoth`), `preferSchemaTypeProperty` (`typeof WidgetId.Type`), `preferSucceedSomeOrNone`
  (`Effect.succeedSome`), `yieldInCallArgument` (tests yield into a constant before they assert), and
  `strictEffectProvide` (composition roots end in `NodeRuntime.runMain`). The raw `fetch` example disables
  `globalFetchInEffect` on its line with a reason.
- The stability notes add the platform services, the crypto families, `@effect/platform-node`, and `@effect/vitest`
  to the unstable modules.
- `PLATFORM_NODE.md` notes that the Effect preset rejects `node:*` imports, so edge files need a consumer override.
- The Redis example decodes the reply with Schema instead of a `string | null` type argument, which
  `prefer-option-over-null` rejects.
- Examples that declared `_tag` by hand use `Data.TaggedEnum` and `Request.TaggedClass`, as
  `flo-effect/no-manual-tagged-type` requires.
- Operations in the object a service's `make` returns carry an inline span, or name a value that `make` binds to
  a spanned value, as `flo-effect/require-operation-span` requires. `SERVICES_LAYERS.md` says how to return an
  extracted operation.
- `references/REVIEW_QUESTIONS.md` restates the review questions from upstream `src/jev/effect-rules.ts` (the
  source questions and the test question) as written guidance. The review checklist links to it.
- `SERVICES_LAYERS.md` adds a section, written for this package, on effects that run outside the caller's fiber. A
  callback from a non-Effect library runs its effect with `Effect.runPromiseWith(context)` or another
  `Effect.run*With`. An Effect value that a library or a cache runs later closes over each yielded service with
  `Effect.provideService` inside a function, because a captured context provided back moves its spans under the span
  that built the service.
- Smaller fixes: regular expressions use the `u` flag, `5_000` is `5000`, an object type alias is an interface, and
  `yield *` typos are `yield*`.
