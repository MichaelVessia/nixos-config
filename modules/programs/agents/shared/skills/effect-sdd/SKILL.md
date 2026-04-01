---
name: effect-sdd
description: "Service-Driven Development workflow for Effect-TS. Schema-first, type-driven, property-tested. USE THIS SKILL WHEN: Designing a new feature spanning 3+ services, sketching service boundaries before implementation, user says 'design', 'sketch', 'SDD', 'service-driven', planning multi-service composition. NOT FOR: single-service CRUD, implementing against an existing spec. TRIGGERS ON: 'design services', 'sketch services', 'SDD', 'service-driven', 'type-driven design', 'design the API first', 'audit services', 'bring to SDD standard', 'SDD audit'"
version: 1.0.0
---

# Service-Driven Development (SDD)

Design services as pure type-level interfaces. Constrain them with Schema. Test them with properties. Compose them. Iterate until the API is right. THEN implement.

**The orchestrator defines the perfect DSL.** You write the top-level composition first — as if ideal services already exist. The interfaces emerge from what the orchestrator needs, not from independent design.

> "Code the simple version first. Code it _before_ you have implemented the sub-layers. Just imagine they exist. Code as if the perfect API to implement this layer already existed. Then, once your code looks beautiful, go implement those things." — Grant Slatton

**Why top-down?** Bottom-up locks you into a design before you've written the software. When you implement layer N, you guess what layer N+1 needs. When you get to N+1, you work around a not-quite-right API you're hesitant to change. Top-down avoids this — each layer defines what the layer below should be.

## Phase Map

> **CRITICAL**: Before starting any phase, READ its reference doc. Each contains the gate criteria, required patterns, and anti-patterns for that phase.

| Phase | Name | Gate | Reference |
|-------|------|------|-----------|
| 1 | **Model** | tsc clean + property tests pass + ELS clean | [phase-1-model.md](references/phase-1-model.md) |
| 1.5 | **Review** | API review checklist passed | [phase-2-validate.md](references/phase-2-validate.md) §Review |
| 2 | **Validate** | orchestration tests pass in @effect/vitest | [phase-2-validate.md](references/phase-2-validate.md) |
| 3 | **Implement** | contract tests pass against real layers | [phase-3-implement.md](references/phase-3-implement.md) |
| 4 | **Wire** | boundary tests pass + branch coverage target met | [phase-4-wire.md](references/phase-4-wire.md) |
| 5 | **Verify** | CLI smoke tests pass + structured logs confirmed | [phase-5-verify.md](references/phase-5-verify.md) |

## Phase 1: Model

**Single file.** Schema domain models with constraints, Context.Tag service interfaces, orchestrator implementation, and property tests for all schemas.

The schema IS the constraint system. Every field gets evaluated: NonEmptyString? pattern()? between()? The property tests co-designed with schemas force constraint thinking.

**Speed matters here.** The sketch is intentionally disposable — find interface problems fast, don't polish. You can always backtrack and delete. A 30-minute sketch that reveals a bad decomposition saves 3 hours of implementation.

**Output:** One `.sketch.ts` file + one `.test.ts` file. Both typecheck.

-> Read [phase-1-model.md](references/phase-1-model.md)

## Phase 1.5: API Review (Deletion Pass)

**Before writing any implementation.** A fresh reviewer examines the Context.Tag interfaces. Apply Musk's first three steps: question every requirement, delete aggressively, then simplify what remains.

1. **One sentence per service.** Can't? Split it.
2. **Gun to the head.** What's the absolute minimum? Delete anything that exists "in case" or "for completeness."
3. **If you haven't deleted at least 1 service or 3 methods, you weren't aggressive enough.** The bias is always to add — force deletion first.
4. **Error channel audit.** Does the orchestrator's inferred error type make sense?

> "The most common error of a smart engineer is to optimize something that should simply not exist." — Elon Musk

-> Read [phase-2-validate.md](references/phase-2-validate.md) §API Review

## Phase 2: Validate

**Layer.mock stubs.** Prove orchestration logic with @effect/vitest tests. Not bun scripts — real vitest suites with `it.effect()` and `it.effect.prop()`.

**Output:** `test/` directory with orchestration + property test suites. All pass.

-> Read [phase-2-validate.md](references/phase-2-validate.md)

## Phase 3: Implement

**Real layers.** Split sketch into modules. Contract tests run against real implementations. Reference-model tests compare Layer.mock vs real Layer — same operations, same results.

**Output:** Module files + contract test suites + reference-model tests. All pass.

-> Read [phase-3-implement.md](references/phase-3-implement.md)

## Phase 4: Wire

**CLI/API integration.** Error boundary mapping (catchTag chains). Integration tests. Branch coverage gate.

**Orchestrator executes this phase** — not delegated to sub-agents. Boundary code crosses module boundaries and requires understanding the full error architecture.

-> Read [phase-4-wire.md](references/phase-4-wire.md)

## Phase 5: Verify

**Runtime smoke test.** Run actual CLI commands. Verify structured logs include Effect.fn spans and annotateLogs annotations. Confirm tsc + ELS clean. All tests pass. Zero regressions.

**This is the "it actually works" gate.** Tests prove correctness in isolation. Phase 5 proves it works when composed into the real application.

-> Read [phase-5-verify.md](references/phase-5-verify.md)

## Testing Strategy

Testing is a GRADIENT, not a phase. It increases monotonically across all phases:

| Phase | What's tested |
|-------|--------------|
| 1 Model | Schema roundtrips + branded type invariants + algebraic properties |
| 2 Validate | + orchestration with Layer.mock + error propagation |
| 3 Implement | + contract tests against real layers + reference-model comparison |
| 4 Wire | + boundary tests + integration tests + coverage gate |
| 5 Verify | + CLI smoke tests + structured log confirmation + regression check |

Three-tier property testing (Slatton): reference-model -> invariant -> crash. All mandatory.

-> Read [testing.md](references/testing.md)

## Gates (Run at Every Phase Transition)

```bash
# TypeScript (standard)
npx tsc -p tsconfig.json --noEmit

# Effect Language Service (quick fixes + diagnostics)
npx effect-language-service quickfixes --project tsconfig.json

# Tests
npx vitest run

# Coverage (Phase 4)
npx vitest run --coverage --coverage.branches=100
```

Zero diagnostics. Zero warnings. All tests pass. No exceptions.

## When to Go Back

| Signal | Go back to |
|--------|-----------|
| Orchestrator feels wrong | Phase 1 — reshape interfaces |
| Test reveals missing method | Phase 1 — add to Context.Tag |
| Implementation reveals interface is unimplementable | Phase 1 — DELETE sketch, redesign |
| Agent output doesn't fit | Phase 1 — the interface was wrong |
| Coverage gap in domain code | Phase 3 — add contract/property tests |

**Backtrack, don't force.** If a Context.Tag can't be implemented, delete and redesign. The sketch is disposable — it's the first pass, the implementation is the rewrite.

## Context.Tag vs Effect.Service

| Phase | Use | Why |
|-------|-----|-----|
| Design (sketch) | `Context.Tag` | No implementation required. Pure interface. |
| Implementation | Either | `Context.Tag + Layer.effect` for swappable. `Effect.Service` for single impl. |
| Testing | `Layer.mock` / `Layer.succeed` | Mock for partial stubs. Succeed for full doubles. |

## Audit Mode (Existing Code)

SDD isn't only for greenfield. **Audit mode** brings existing Effect service code up to SDD standard.

Walk forward through phases 1->4, evaluate every gate. Then decide: **remediate** (patch gaps) or **rewrite** (the first impl was the prototype — rebuild properly from Phase 1).

- **Remediate**: architecture sound, gaps localized, <5 files. Output = remediation DAG tracked via markdown checklist or task graph tool.
- **Rewrite**: majority of phases FAIL, schema changes cascade everywhere, you'd touch every file anyway. Output = standard SDD workflow with the old code as your spec.

-> Read [audit.md](references/audit.md)

## Effect Idiom Enforcement

These violations were found across ALL models in blind testing. They're easy to write, hard to catch in review. Check explicitly.

### Impure Operations Must Be Wrapped

```typescript
// BAD — side effect escapes Effect tracking
const id = crypto.randomUUID()

// GOOD — Effect tracks the impure operation
const id = yield* Effect.sync(() => crypto.randomUUID())

// BAD — DateTime.unsafeNow bypasses Effect
const now = DateTime.unsafeNow

// GOOD — DateTime.now returns Effect<DateTime.Utc>
const now = yield* DateTime.now
```

### Match, Never Switch

```typescript
// BAD — switch on _tag loses exhaustiveness
switch (event._tag) {
  case "Click": return "engaged"
  default: return "anonymous"  // silent bug if new event added
}

// GOOD — Match.exhaustive is compile-time checked
Match.value(event).pipe(
  Match.tag("Click", () => "engaged"),
  Match.tag("Signup", () => "lead"),
  Match.exhaustive  // <- compiler error if case missing
)
```

### Mutable Accumulation

```typescript
// BAD — imperative loop with mutation
let total = 0
for (const e of events) { total += e.count }

// GOOD — functional fold
const total = events.reduce((acc, e) => acc + e.count, 0)

// GOOD (effectful) — for tracked accumulation
const total = yield* Ref.make(0)
yield* Effect.forEach(events, (e) => Ref.update(total, (n) => n + e.count))
```

### Patterns That LOOK Wrong But Are Correct

- `Effect.fn("name")(function* () { ... })` — **this IS the canonical Effect.fn pattern** per docs
- Both `Schema.OptionFromNullOr` and `Schema.OptionFromUndefinedOr` are valid — use `FromNullOr` for JSON-encoded data, `FromUndefinedOr` for JS object properties

## Verification with effect-mcp

If you have effect-mcp configured, **verify APIs before writing**. Use the `effect_docs_search` and `get_effect_doc` MCP tools:

1. **Before Phase 1**: Search for `Schema.Class`, `Schema.TaggedError`, `Context.Tag` to confirm current API shapes
2. **During Phase 1**: When unsure about a Schema combinator (e.g., "is it `Schema.OptionFromNullOr` or `Schema.optional`?"), search effect-mcp
3. **During Phase 3**: Verify `Effect.fn`, `Layer.effect`, `Layer.mock` signatures
4. **At every gate**: Run `npx tsc --noEmit` AND `npx effect-language-service quickfixes --project tsconfig.json`

Otherwise, check https://effect.website/docs for API reference.

The Effect Language Service catches issues that tsc misses — missing service providers, unnecessary `Effect.gen` wrapping, and more.

## Architectural Patterns (From Experiment)

Patterns that consistently produced better output in blind testing:

1. **Helper functions in models.ts** — pure domain logic (`isValidTransition`, `targetStageForEvent`) separate from orchestration. Every future orchestrator gets these for free.
2. **Options-object pattern on queries** — `query({ personId?, limit?, since? })` instead of `queryByPerson`, `queryBySince`, etc. Extensible without breaking callers.
3. **Effect.fn on ALL orchestrators** — not just service methods. Tracing at the orchestration level is where you diagnose production issues.
4. **Match.tags for grouped handling** — `Match.tags({ Click: () => ..., Follow: () => ... })` instead of chaining `.tag()` calls.
5. **Effect.all for parallel composition** — `Effect.all([a(), b(), c()])` for independent operations in dashboard/summary orchestrators.

## Pre-SDD: Decision Razors

SDD answers HOW to build. It assumes you've already decided WHAT to build. If available, apply Decision Razors first to define scope. Otherwise, manually answer:

- **Why does this deserve to exist?** (income leverage, user value)
- **What's the minimum scope?** (delete 90% of imagined features)
- **What ships this week?** (crudest version that validates the hypothesis)

Apply razors first. Then enter SDD with a clear, minimal scope.

## Integration

- **effect-best-practices skill**: Effect idioms during implementation
- **ELS CLI**: Gate enforcement at every transition
- **effect-mcp**: API verification via `effect_docs_search` + `get_effect_doc` (if configured)
- (optional) Task graph tool for remediation DAG tracking in audit mode
