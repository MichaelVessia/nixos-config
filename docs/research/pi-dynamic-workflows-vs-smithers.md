# Research: `pi-dynamic-workflows` vs. Smithers

## Summary

`pi-dynamic-workflows` is a small, Pi-native fan-out/fan-in primitive: the parent model generates a deterministic JavaScript script, the extension executes it in a Node `vm`, and `agent()` creates fresh in-memory Pi sessions. It is well suited to short, interactive repository audits, parallel research, and multi-perspective review, but it has no durable run state, automatic retries, approvals, resume, or independent control plane.

Smithers is a much broader durable workflow runtime. Its React/JSX reconciler repeatedly renders a task graph from persisted state, schedules ready nodes, validates and stores typed outputs, and re-renders; it adds retries, approval/signal waits, crash recovery, time travel, a CLI/Gateway, and observability. The practical choice is therefore not “two equivalent DSLs”: use `pi-dynamic-workflows` for lightweight orchestration inside the current Pi turn, and Smithers for long-running, resumable, operationally visible workflows.

## Installation and enablement verification

**Verified installed:** `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/package.json` exists and identifies `pi-dynamic-workflows` version **1.0.1**, with `extensions/workflow.ts` declared under `pi.extensions`. The installed README and TypeScript source are also present under that directory.

**Verified configured globally:** `/Users/michael.vessia/.pi/agent/settings.json`, JSON path `packages[12].source`, contains `"npm:pi-dynamic-workflows"`. Pi's official package documentation says resources declared under a package's `pi` key are loaded from installed npm/git packages, while global settings apply across projects ([Pi packages](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md), [Pi settings](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md)).

**Verified activation behavior:** `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/extensions/workflow.ts`, default `extension()` function, registers the `workflow` tool and handles `session_start` by adding it to the active-tool list when absent. Thus the user's global package setting causes discovery, and the extension actively enables its tool when a Pi session starts. This verifies installation and configured enablement; it does not independently inspect the live tool list of an already-running Pi process.

## Findings

### 1. Architecture and orchestration model

| Dimension | `pi-dynamic-workflows` | Smithers |
|---|---|---|
| Core architecture | One Pi extension registering one `workflow` tool. A model-authored JS script is AST-checked, evaluated in a Node `vm`, and calls in-process orchestration globals. Each `agent()` creates a fresh, in-memory Pi `AgentSession`. Local sources: `src/workflow-tool.ts` (`createWorkflowTool`), `src/workflow.ts` (`runWorkflow`), `src/agent.ts` (`WorkflowAgent.run`). | A React reconciler whose host elements are workflow tasks. Each frame is **render → extract → schedule → execute → persist → re-render**; persisted state is the source of truth. [How It Works](https://smithers.sh/how-it-works) |
| Plan shape | Imperative/dynamic script authored ad hoc by the parent model. Runtime `if`, loops, and ordinary JS naturally determine which phases and agents appear. | Declarative React/JSX graph derived from `smithers(ctx => ...)`; conditionals and `.map()` alter rendered nodes, while `<Sequence>`, `<Parallel>`, `<Branch>`, and `<Loop>` define graph control flow. [JSX API](https://smithers.sh/jsx/overview) |
| Agent lifecycle | Every call starts an isolated **conversation/session**, but all agents receive the same working directory and standard Pi coding tools by default. Sessions are disposed after the call. | Tasks may use SDK agents in-process or CLI agents as child processes; durable task/session snapshots allow later tasks to `fork` prior agent context. [How It Works](https://smithers.sh/how-it-works), [Task](https://smithers.sh/components/task) |

The Pi extension is primarily a dynamic fan-out helper embedded in an existing conversation. Smithers is an external workflow engine and state machine that can itself invoke Pi via `PiAgent`; Smithers' official Pi integration explicitly positions Pi as adaptive agent capability and Smithers as deterministic orchestration with approvals, retries, and durable state ([Pi Integration](https://smithers.sh/integrations/pi-integration)).

### 2. API and DSL

**`pi-dynamic-workflows`.** The tool accepts `{ script, args? }`. The script's first statement must be a literal:

```js
export const meta = { name: "...", description: "...", phases: [...] }
```

It then uses globals `agent(prompt, opts)`, `parallel(thunks)`, `pipeline(items, ...stages)`, `phase(title)`, `log(message)`, `args`, `cwd`, and `budget`. `parallel` preserves input order; `pipeline` runs stages sequentially per item while items fan out. The exact public declarations are in `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/types/workflow.d.ts`; implementation and validation are in `src/workflow.ts` (`parseWorkflowScript`, `runWorkflow`) and tool guidance in `src/workflow-tool.ts` (`workflowToolSchema`, `createWorkflowTool`).

**Smithers.** `createSmithers({...Zod schemas...})` produces typed workflow components and output targets; a workflow default-exports `smithers(ctx => <Workflow>...</Workflow>)`. `<Task>` supports agent, compute, or static modes; graph primitives include sequence, parallel, branch, loop, approvals, signals, worktrees, and sandboxes. Dependencies can be ordering-only (`dependsOn`), named (`needs`), or typed output dependencies (`deps`). [JSX API](https://smithers.sh/jsx/overview), [Task](https://smithers.sh/components/task)

Smithers also exposes a programmatic `runWorkflow()` and CLI. The Pi extension exposes its runtime as a Pi tool (and npm library modules), but its normal UX is model-generated, one-off script execution rather than managing named durable workflows.

### 3. Concurrency

- **Pi extension:** `runWorkflow()` creates one shared limiter. Default concurrency is `hardwareConcurrency - 2`, falling back from 8, clamped to **1–16**; an extension option may override it but the installed entrypoint calls `createWorkflowTool()` without an override. `parallel()` uses `Promise.all`; `pipeline()` concurrently maps items but serializes each item's stages. Source: local `src/workflow.ts`, `runWorkflow()` and `createLimiter()`.
- **Smithers:** the scheduler computes ready tasks from graph dependencies and global `RunOptions.maxConcurrency` (documented default **4**). `<Parallel maxConcurrency>` and `<MergeQueue maxConcurrency>` add scoped limits. [How It Works](https://smithers.sh/how-it-works), [Parallel](https://smithers.sh/components/parallel)

Both support bounded parallelism, but Smithers' concurrency is graph-aware and durable; the Pi extension's is a process-local promise limiter.

### 4. State and context passing

- **Pi extension:** `args` is immutable caller-supplied input. Agent results are ordinary JS values and must be manually interpolated into later prompts or returned. Agents do not inherit the parent's conversation or another agent's conversation. Workflow-level `logs`, phases, agent count, result, and duration are collected only in memory. The final result must be structured-cloneable. Source: local `src/workflow.ts`, `runWorkflow()`; `src/agent.ts`, `WorkflowAgent.run()`.
- **Smithers:** immutable `ctx.input` and typed task outputs are persisted. `ctx.output`, `outputMaybe`, `outputs`, `latest`, and iteration-aware accessors read durable rows keyed by run, node, and iteration. `deps` passes typed upstream rows to task callbacks. Agent session snapshots are durable and `fork` starts a new task from a copy of previous context. [How It Works](https://smithers.sh/how-it-works), [Task](https://smithers.sh/components/task)

Smithers therefore has explicit dataflow and optional conversational continuity; `pi-dynamic-workflows` has value passing only, with intentionally fresh subagent sessions.

### 5. Structured outputs

- **Pi extension:** `agent(..., { schema: <JSON Schema> })` adds a Pi `structured_output` tool. Pi validates tool parameters, captures the value, and returns `terminate: true`, avoiding another assistant turn. If the agent never calls the tool, the task fails. Sources: local `src/structured-output.ts`, `createStructuredOutputTool()`; `src/agent.ts`, `WorkflowAgent.run()`.
- **Smithers:** Zod schemas registered with `createSmithers` become typed output targets and persisted tables. Native-capable SDK agents receive the schema through the AI SDK structured-output channel; CLI agents receive JSON instructions followed by parsing/validation. Invalid output can receive up to `maxSchemaRetries` correction calls without consuming ordinary task retries. [How It Works](https://smithers.sh/how-it-works), [Task](https://smithers.sh/components/task)

Both validate machine-readable agent results. Smithers' outputs are first-class durable workflow state with typed dependencies and correction behavior; Pi's are per-call return values.

### 6. Retries, failure, cancellation, and human intervention

| Capability | `pi-dynamic-workflows` | Smithers |
|---|---|---|
| Automatic retry | **None.** `agent()` catches non-abort failures, logs them, and returns `null`; `parallel()`/`pipeline()` similarly convert branch failures to `null`. A script may explicitly call another agent after checking `null`. | Per-task retries, backoff policy, timeouts, schema-correction retries, fallback agents, stale-attempt recovery, and `continueOnFail`. [Task](https://smithers.sh/components/task), [Recipes](https://smithers.sh/recipes) |
| Cancellation | The Pi tool forwards its `AbortSignal`; Esc aborts active sessions, running rows become skipped, and the tool throws “Workflow was aborted.” Local `src/workflow-tool.ts`, `execute()` abort branch; `src/agent.ts`, abort listener. | `AbortSignal`, CLI/Gateway cancellation, run status `cancelled`, and propagation through active work. Durable waits exit cleanly rather than holding a process. [runWorkflow](https://smithers.sh/runtime/run-workflow), [CLI](https://smithers.sh/cli/overview) |
| Human-in-loop | None built into the workflow primitive. | Durable `<Approval>`, task approval gates, signals, timers, and structured `<HumanTask>`; decisions survive process exit. [How It Works](https://smithers.sh/how-it-works) |

**Risk — High for unattended/long runs:** local `src/workflow.ts` deliberately converts most subagent failures to `null`, and there is no durable checkpoint. A parent-process crash or terminal exit loses completed workflow state and requires rerunning the whole tool.

### 7. Observability and UI

- **Pi extension:** compact inline Pi TUI snapshots show phases, up to four agent rows, one log line, status, and duration; the renderer deliberately hides result previews by default. The final tool result contains snapshot details and JSON. Cancellation uses the ordinary Pi interaction. Source: local `src/workflow-tool.ts`, `workflowDisplayOptions`, callbacks, and `renderResult`; local `src/display.ts`.
- **Smithers:** lifecycle transitions form a durable, ordered event log in the database and NDJSON. CLI `what`/`why`, a full-screen TUI, local Monitor UI, Gateway WebSocket/RPC, browser SDKs, OTel traces/logs, Prometheus metrics, and timeline/fork/diff views derive from that record. It has no hosted Smithers cloud dashboard; operators run the Monitor and/or their own telemetry stack. [Observability](https://smithers.sh/capabilities/observability), [CLI](https://smithers.sh/cli/overview)

Pi's UI is excellent for one interactive invocation; Smithers is designed for post-mortem and multi-process operations.

### 8. Persistence, resume, and time travel

`pi-dynamic-workflows` uses `SessionManager.inMemory()` and disposes each subagent session. Its README explicitly says persisted/resumable runs and a `/workflows` manager are not implemented. There is no run ID, checkpoint, cache, approval state, replay, or resume. Sources: local `src/agent.ts`, `WorkflowAgent.run()`; local `README.md`, **Status**.

Smithers persists validated outputs, attempts, events, graph frames, approval/signal state, and agent snapshots. Resume skips completed tasks, abandons stale in-flight attempts, validates source/VCS identity, and continues from the last frame. Timeline, replay, fork, diff, and JJ-backed workspace restore provide time travel. SQLite is the default documented local store; release 0.23.0 also documents PostgreSQL/PGlite support and durable workspace snapshots. [How It Works](https://smithers.sh/how-it-works), [runWorkflow](https://smithers.sh/runtime/run-workflow), [0.23.0](https://smithers.sh/changelogs/0.23.0)

### 9. Isolation and security

**Pi workflow-script sandbox.** The script runs in a Node `vm` context with no direct `require`, imports, `fs`, or network globals. The parser rejects `Date.now()`, `Math.random()`, `new Date()`, and non-literal metadata constructs. Source: local `src/workflow.ts`, `assertDeterministicAst()`, `evaluateLiteral()`, and `vm.createContext(...)`.

**Important limitation — High if `isolation: "worktree"` is trusted as enforcement:** `AgentOptions` accepts `isolation` and `model`, but `buildAgentInstructions()` only turns both into natural-language instructions. `WorkflowAgent.run()` still uses the same `cwd` and `createCodingTools(this.cwd)`; it does not create a worktree or sandbox. Thus “isolated subagent” means fresh conversational session, **not filesystem/process isolation**. Sources: local `src/workflow.ts`, `normalizeAgentOptions()` and `buildAgentInstructions()`; local `src/agent.ts`, constructor and `createAgentSession(...)`.

A second reproducibility limitation is that the AST check is syntactic rather than a capability membrane: the context still exposes the `Math` object. The direct forms are rejected, but the source does not establish a hardened security boundary. Treat the workflow script as model-generated trusted-local code, and its subagents as normal Pi coding agents with host workspace tools.

**Smithers.** Its built-in `read`/`write`/`edit`/`grep`/`bash` tools restrict paths to `rootDir`, reject escaping symlinks, limit output/time, and block network-oriented commands by default unless `allowNetwork` is set. Tools can be granted per task; side effects and idempotency keys are tracked. However, official docs are explicit that SDK agents run in-process and CLI agents run as host child processes by default—there is no automatic container per task. `<Worktree>` isolates VCS work, while `<Sandbox>` with a provider is required for a stronger execution boundary. [Built-in Tools](https://smithers.sh/integrations/tools), [Worktree](https://smithers.sh/components/worktree), [Sandbox](https://smithers.sh/components/sandbox), [Execution Model](https://smithers.sh/concepts/execution-model)

Smithers supplies substantially more enforceable least-privilege machinery, but neither product should be described as automatically container-isolated in its default path.

### 10. Model and provider flexibility

- The installed Pi extension passes the parent's current `ctx.model` and model registry into every subagent session (`src/workflow-tool.ts`, `execute()`), so all extension-created agents normally use the active Pi model/provider. The user's `/Users/michael.vessia/.pi/agent/settings.json` currently defaults to `openai-codex/gpt-5.6-sol` and lists only OpenAI Codex models as enabled.
- **Limitation — Medium:** per-agent `opts.model` does not select a model; it merely adds `Requested model: ...` to the prompt via `buildAgentInstructions()`. The library-level `WorkflowAgentOptions.session` can override Pi session creation, but the installed tool DSL does not wire `opts.model` to that mechanism.
- Smithers can mix agent implementations task by task: Anthropic/OpenAI/Hermes SDK agents, CLI-backed Claude Code, Codex, Pi, OpenCode and others, plus fallback arrays. `PiAgent` exposes Pi provider/model/tools/extensions/skills flags. [SDK Agents](https://smithers.sh/integrations/sdk-agents), [CLI Agents](https://smithers.sh/integrations/cli-agents), [Pi Integration](https://smithers.sh/integrations/pi-integration)

Pi itself is provider-flexible, but this extension's installed DSL effectively shares one active model across the run. Smithers makes model/harness selection an explicit per-task graph property.

### 11. Intended use cases and ecosystem maturity

**`pi-dynamic-workflows`:** its installed README names codebase audits, multi-perspective review, large refactors, and fan-out research. The README explicitly labels it a **prototype**. Version 1.0.1 has a compact implementation centered on five source modules, one extension entrypoint, parser tests, and no workflow manager or persistence. Its strongest value is minimal friction: installation adds a tool directly to Pi and the model can synthesize the workflow from plain language.

**Smithers:** official materials target long-horizon coding and operational workflows lasting minutes or days, with approvals, retries, worktrees/sandboxes, deployment, monitoring, and recovery. The public repository is MIT licensed and includes runtime, CLI, Gateway, SDKs, docs, examples, and workflow packs ([official repository](https://github.com/smithersai/smithers), [Introduction](https://smithers.sh/introduction)). Official site claims include 100+ runnable examples and 6+ ecosystem projects; changelog 0.23.0 documents a rapidly expanding runtime and UI/storage surface. This is materially broader and more mature than the Pi prototype, though the **0.x version and frequent API/release changes** indicate continued evolution rather than a settled platform. [Smithers site](https://smithers.sh/), [0.23.0](https://smithers.sh/changelogs/0.23.0)

## Recommendation

- Choose **`pi-dynamic-workflows`** when the work fits one attended Pi session, decomposes into independent investigations, can tolerate best-effort `null` branches, should use the current Pi model/tools, and does not require durable checkpoints.
- Choose **Smithers** when a run may outlive the terminal/process, needs typed durable state, retries/timeouts, approval gates, mixed models/harnesses, per-task permissions/worktrees/sandboxes, resumability, or operator-facing observability.
- They can complement each other: Smithers can run Pi as a task agent. For durable orchestration, prefer Smithers' graph and use `PiAgent` where Pi's extension/skill/provider ecosystem is useful; do not wrap a long-running Smithers-like job in the in-memory Pi workflow primitive.

## Sources

### Kept (primary sources only)

- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/package.json` — installed identity, version, extension manifest, repository, and dependency surface.
- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/README.md` — installed package's documented usage, architecture, intended use, and prototype status.
- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/src/workflow.ts` — parser, VM context, concurrency, error semantics, data passing, budget, and option handling.
- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/src/workflow-tool.ts` — Pi tool API, activation-time model wiring, cancellation, and inline UI behavior.
- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/src/agent.ts` — in-memory Pi sessions, shared working directory/tools, and abort handling.
- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/src/structured-output.ts` — validated terminating output tool.
- `/Users/michael.vessia/.pi/agent/npm/node_modules/pi-dynamic-workflows/extensions/workflow.ts` — tool registration and `session_start` activation.
- `/Users/michael.vessia/.pi/agent/settings.json` — this user's global package registration and model configuration.
- [Official Pi packages](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md) and [settings](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md) — official loading/config semantics.
- [Smithers: How It Works](https://smithers.sh/how-it-works) — canonical architecture, context, persistence, task, isolation, and resume description.
- [Smithers JSX API](https://smithers.sh/jsx/overview) and [Task](https://smithers.sh/components/task) — DSL, dependencies, schemas, retries, and session forks.
- [Smithers Observability](https://smithers.sh/capabilities/observability) — event log, UI, Gateway, OTel, and stated limitations.
- [Smithers Built-in Tools](https://smithers.sh/integrations/tools) — sandbox policy and side-effect tracking.
- [Smithers Pi Integration](https://smithers.sh/integrations/pi-integration) — first-party division of responsibility and Pi adapter behavior.
- [Official Smithers repository](https://github.com/smithersai/smithers) and [0.23.0 changelog](https://smithers.sh/changelogs/0.23.0) — repository scope and current evolution.

### Dropped

- Third-party blogs, comparison posts, package aggregators, and search-result commentary — excluded by the primary-source-only requirement.
- Smithers' comparisons to other orchestration/observability products — excluded because those claims were unnecessary to answer this comparison and would require verification from each project's own sources.
- npm download counts and GitHub-star-based maturity judgments — excluded because popularity is volatile and weaker than source/docs/release evidence.

## Gaps and residual uncertainty

1. No live Pi introspection command was available in this research environment, so enablement is established from the installed manifest, global settings, and extension activation source—not from a runtime `getActiveTools()` snapshot.
2. No workflow was executed. Runtime behavior is based on the exact installed 1.0.1 source and official Smithers documentation, not a comparative benchmark.
3. Smithers is moving quickly. The official site currently surfaces 0.23.0-era features; verify the pinned npm version and migration notes before adoption.
4. The Pi extension's VM restrictions were source-reviewed, not penetration-tested. Node `vm` should not be treated as a complete untrusted-code security boundary based on these sources alone.

## Acceptance report

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Concrete comparison and risks include precise local paths and symbols; installation is evidenced by package.json, settings.json packages[12], and extensions/workflow.ts activation logic."
    }
  ],
  "changedFiles": [
    ".pi-subagents/artifacts/outputs/688290d6-1140-4f68-9b80-41926ef38fe1/research.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "Runtime shell tests and git status",
      "result": "not-run",
      "summary": "No shell execution tool was available; exact installed files were read directly and official primary sources were fetched."
    }
  ],
  "validationOutput": [
    "Read installed package.json: pi-dynamic-workflows version 1.0.1 with pi.extensions = extensions/workflow.ts.",
    "Read global settings.json: packages[12].source = npm:pi-dynamic-workflows.",
    "Read extension source: registers workflow and activates it on session_start.",
    "Compared local implementation with official Smithers and Pi documentation only."
  ],
  "residualRisks": [
    "Live active-tool state was not queried.",
    "No comparative workflow benchmark was executed.",
    "Smithers documentation reflects a rapidly evolving 0.x release line."
  ],
  "noStagedFiles": true,
  "diffSummary": "Added one research artifact; no configuration or package source files were modified and this agent staged no files.",
  "reviewFindings": [
    "high: pi-dynamic-workflows src/workflow.ts buildAgentInstructions() - isolation: worktree is prompt text only, not enforced isolation.",
    "high: pi-dynamic-workflows src/workflow.ts runWorkflow() - no persistence or automatic retry; most branch failures become null.",
    "medium: pi-dynamic-workflows src/workflow.ts buildAgentInstructions() - per-agent model option does not switch the session model.",
    "no blockers in the research artifact"
  ],
  "manualNotes": "noStagedFiles means this agent did not stage files; repository-wide index state could not be checked without a shell tool."
}
```
