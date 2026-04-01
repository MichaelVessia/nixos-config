# Audit Mode: Bringing Existing Code to SDD Standard

## When to Use Audit Mode

- Existing Effect service code that wasn't built with SDD
- Code that partially follows SDD but has gaps (e.g., no tests, bare schemas)
- Post-implementation quality review ("does this meet the gate?")
- Refactoring code from ad-hoc to SDD compliance

**NOT for:** Greenfield features (use the standard phase workflow). If the code doesn't exist yet, don't audit — build it right.

---

## The Decision: Remediate or Rewrite?

After the audit produces its findings, make this call BEFORE starting any fixes.

### Remediate When:
- Architecture is sound (service decomposition, error architecture, Layer composition all PASS)
- Gaps are localized (<5 files need changes)
- Existing consumers depend on the exact API shape
- Most phases are PARTIAL, not FAIL

### Rewrite When:
- Majority of phases FAIL (not PARTIAL)
- Schema constraints need deep rework that cascades through call sites
- You'd end up touching every file anyway
- Testing is absent enough that you're building all test infrastructure from scratch
- The original code IS the spec for the rewrite (Slatton's "write twice")

**The rewrite path IS the standard SDD phase workflow** — but you already know what the services should look like. The first implementation was the prototype. You learned the right decomposition, the right error boundaries, the right orchestrator shape. Now build it properly from Phase 1 with tests at every gate.

Rewrite advantages:
- Every phase gate is closed from the start (no remediation debt)
- Property tests co-designed with schemas catch constraint issues early
- Clean module structure (no archaeological layers from incremental patching)
- Often FASTER than remediation when >50% of files need changes

### Hybrid: Rewrite the Module, Keep the Wiring

Common pattern: the service implementation gets rewritten (new package or new module directory), but Phase 4 wiring (CLI commands, Layer composition) stays and just points at the new module. The boundary code rarely needs rewriting — it was the last thing built and usually the most correct part.

---

## Audit Walkthrough

Walk FORWARD through phases 1->4. For each phase, evaluate every gate criterion. The output is a **remediation DAG** — a dependency graph of fixes, not a flat list.

### Step 1: Read the Code

Before auditing, read ALL implementation files:
- Domain models (schemas, branded types, errors)
- Service interfaces (Context.Tag definitions)
- Implementations (Layer.effect / Layer.succeed / Effect.Service)
- Orchestrator(s)
- Test files (if any)
- CLI wiring (command handlers, Layer composition)

### Step 2: Phase-by-Phase Gate Check

For each phase, evaluate every gate criterion from its reference doc. Score each as:

| Verdict | Meaning |
|---------|---------|
| **PASS** | Gate criterion fully met |
| **PARTIAL** | Started but incomplete (e.g., Effect.fn on 4/6 services) |
| **MISSING** | Not done at all |
| **VIOLATION** | Done wrong (e.g., Effect.fail(new TaggedError) instead of yield*) |

### Step 3: Produce Remediation Items

Each gate failure becomes a remediation item with:

```markdown
### [P{priority}] {Phase}.{Gate}: {Short description}

**Verdict**: MISSING | PARTIAL | VIOLATION
**Files**: file.ts:line, file2.ts:line
**What's wrong**: {specific description}
**Fix**: {concrete action}
**Blocked by**: {other item IDs, if any}
**Estimated scope**: {small | medium | large}
```

### Step 4: Build the DAG

Remediation items have natural dependencies:

```
Phase 1: Schema constraints
  |-> Phase 1: Property tests (need constrained schemas for valid arbitrary data)
       |-> Phase 2: Vitest conversion (property tests go in vitest suites)
            |-> Phase 2: Orchestration tests (extend the vitest suite)
                 |-> Phase 3: Contract tests (extend vitest, swap Layer)
                      |-> Phase 4: Boundary tests
                           |-> Phase 4: Coverage gate
```

Items WITHIN a phase can often parallelize:
- Tightening branded types is independent per type
- Effect.fn migration is independent per service
- annotateLogs is independent per service

### Step 5: Track Remediations

**For 5+ items**: Track as a dependency checklist. If you have a task
graph tool (Linear, GitHub Projects, etc.), use blocks/blockedBy relationships.

```markdown
- [ ] [P0] Tighten schema constraints
- [ ] [P0] Add roundtrip property tests [blocked by: constraints]
- [ ] [P1] Convert tests to vitest [blocked by: property tests]
```

**For <5 items**: Markdown checklist is fine.

---

## Priority Levels

| Priority | Criteria | Examples |
|----------|----------|---------|
| **P0** | Blocks correctness or type safety | Bare branded types, missing property tests, bun scripts instead of vitest |
| **P1** | Blocks testability or error handling | Missing orchestration tests, Layer.succeed instead of Layer.mock, missing boundary tests |
| **P2** | Blocks observability or idiom compliance | Missing Effect.fn, missing annotateLogs, Effect.fail on yieldable errors |
| **P3** | Quality improvement | Reference-model tests, coverage gate, mutable array -> Ref |

**Remediation order**: P0 first (often unblocks P1), then P1, etc. Within a priority level, follow the DAG.

---

## Phase 1 Audit Checklist

| Check | How to Verify |
|-------|--------------|
| Branded types have REAL constraints | Grep for `Schema.String.pipe(Schema.brand` — any without `NonEmptyString`/`pattern`/etc. is a fail |
| Schema.Class fields are constrained | Check every `Schema.String` field — should it be `NonEmptyString`? Every `Schema.Number` — should it be `Int`/`NonNegative`? |
| Schema.TaggedError for all errors | No `Data.TaggedError`, no plain `class extends Error` |
| Property tests exist | Look for `it.prop` / `it.effect.prop` in test files |
| Roundtrip tests for every Schema.Class | Each class gets encode->decode->expect equal |
| Orchestrator composes services | Imports Context.Tags, not implementations |

**Common audit findings:**
- Constraints exist but are misplaced (regex in CLI handler instead of schema)
- Bare brands everywhere (`Schema.String.pipe(Schema.brand("X"))`)
- `Schema.Number` instead of `Schema.Int.pipe(Schema.NonNegative)`
- `Schema.String` for timestamps instead of `Schema.DateTimeUtc`

---

## Phase 2 Audit Checklist

| Check | How to Verify |
|-------|--------------|
| @effect/vitest, not bun scripts | Look for `import { describe, it } from "@effect/vitest"`. Any `Console.log("PASS")` is a fail. |
| Layer.mock for partial stubs | Grep for `Layer.succeed` in test files — should be `Layer.mock` unless ALL methods are intentionally stubbed |
| Happy path tested | At least one `it.effect` that runs the orchestrator with success stubs |
| Each error path tested | Each tagged error type has a test with an error-returning mock |
| Orchestration-level property tests | `it.effect.prop` with Schema-generated inputs |

**Common audit findings:**
- Bun scripts with manual assertions (the #1 anti-pattern)
- Layer.succeed everywhere (can't detect over-broad interfaces)
- Only happy path tested, error paths untested

---

## Phase 3 Audit Checklist

| Check | How to Verify |
|-------|--------------|
| Effect.fn on every service method | Grep for method definitions, verify `Effect.fn("ServiceName.method")` wrapping |
| Effect.annotateLogs at module level | Each service file should have `Effect.annotateLogs("service", "Name")` |
| `yield* new TaggedError()`, not `Effect.fail(new TaggedError())` | Grep for `Effect.fail(new` — TaggedErrors are yieldable |
| No circular imports | Domain models don't import services, services don't cross-import |
| No silent error swallowing | `catchAll(() => succeed(fallback))` without logging is dangerous |
| Contract tests exist | Tests that run against real Layer implementations |
| Reference-model tests exist | Layer.mock vs real Layer comparison |

**Common audit findings:**
- `Effect.withSpan` used instead of `Effect.fn` (close but `Effect.fn` adds argument capture)
- `Effect.fail(new TaggedError(...))` — unnecessary wrapping
- `catchAll` swallowing errors silently (should log warning first)
- Pure helper functions with no unit tests

---

## Phase 4 Audit Checklist

| Check | How to Verify |
|-------|--------------|
| catchTag only for errors IN the channel | Analyze the pipeline's inferred error type — can't catch what's not there |
| Every domain error maps to an exit code | Check exitCodeFor Match.exhaustive |
| Boundary tests exist | Test each catchTag mapping in isolation |
| Layer composition complete | All service layers provided in AppLayer |
| Coverage gate configured | vitest.config.ts has branch coverage thresholds |

**Common audit findings:**
- catchTag for errors that aren't in the error channel (type error)
- Missing service in Layer composition (ELS catches this)
- Zero boundary tests (the mapping chain is untested)

---

## Dispatching Remediation Work

Audit items map cleanly to agent tasks:

| Item Type | Agent Model | Scope |
|-----------|------------|-------|
| Tighten schema constraints | Haiku | Per branded type or Schema.Class |
| Add property tests | Haiku | Per Schema.Class (mechanical) |
| Convert bun script to vitest | Sonnet | Per test file (needs judgment on test structure) |
| Add orchestration tests | Sonnet | Per orchestrator (needs service understanding) |
| Effect.fn migration | Haiku | Per service file (mechanical) |
| Contract tests | Sonnet | Per service (needs IO mocking strategy) |
| Boundary tests | Orchestrator | Per command (crosses module boundaries) |

**The DAG determines dispatch order.** Only dispatch items whose dependencies are met.

---

## Anti-Patterns

- Auditing without reading ALL files first — you'll miss cross-cutting issues
- Flat remediation lists — dependencies matter, use a DAG
- Fixing Phase 3 before Phase 1 — constraints feed property tests feed vitest suites
- Dispatching blocked items — agents will produce wrong code without prerequisite fixes
- Treating "no tests" as one task — it's N tasks with dependencies between them
