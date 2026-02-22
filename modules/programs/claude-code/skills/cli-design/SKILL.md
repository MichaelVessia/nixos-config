---
name: cli-design
description: Design and build agent-first CLIs with JSON envelopes, contextual next_actions, context-safe output, and optional NDJSON streaming. Use when creating CLI tools, adding commands, or reviewing command interfaces for agent consumption.
---

# Agent-First CLI Design

Design CLIs for machine consumption first. Humans can always pipe into `jq`.

## Defaults For This Setup

- Prefer TypeScript + Bun + `@effect/cli` + Effect runtime.
- Keep strict types, no `any`, no non-null assertions, no type assertions.
- If a one-off tool is missing, use `nix run nixpkgs#<pkg>`.
- If tooling should persist, update `flake.nix` (`devShells.default`).

## Core Rules

1. JSON only.
No plain text mode, no table mode, no ANSI formatting.

2. Every response includes next steps.
Include `next_actions` with runnable commands or templates.

3. Root command is self-documenting.
Running the root command with no args returns command tree + usage.

4. Protect context.
Default output is terse, large data is truncated, include pointer to full output.

5. Errors must be actionable.
Return machine error code and a human-readable `fix`.

## Response Contract

Use one envelope for all commands.

```ts
type NextAction = {
  command: string
  description: string
  params?: Record<
    string,
    {
      description?: string
      value?: string | number | boolean
      default?: string | number | boolean
      enum?: ReadonlyArray<string>
      required?: boolean
    }
  >
}

type CliSuccess = {
  ok: true
  command: string
  result: Record<string, unknown>
  next_actions: ReadonlyArray<NextAction>
}

type CliError = {
  ok: false
  command: string
  error: {
    message: string
    code: string
  }
  fix: string
  next_actions: ReadonlyArray<NextAction>
}
```

Template syntax in `next_actions.command`:
- `<arg>` required positional
- `[--flag <value>]` optional flag with value
- `[--flag]` optional boolean flag

## Minimal Examples

Success envelope:

```json
{
  "ok": true,
  "command": "mycli runs get abc123",
  "result": {
    "run_id": "abc123",
    "status": "completed"
  },
  "next_actions": [
    {
      "command": "mycli runs logs <run-id> [--tail <lines>]",
      "description": "View run logs",
      "params": {
        "run-id": { "value": "abc123", "required": true },
        "lines": { "default": 50 }
      }
    }
  ]
}
```

Error envelope:

```json
{
  "ok": false,
  "command": "mycli runs get abc123",
  "error": {
    "message": "Run not found",
    "code": "RUN_NOT_FOUND"
  },
  "fix": "Verify the run id, then list recent runs with mycli runs list",
  "next_actions": [
    {
      "command": "mycli runs list [--limit <n>]",
      "description": "List recent runs",
      "params": {
        "n": { "default": 20 }
      }
    }
  ]
}
```

Root command output:

```json
{
  "ok": true,
  "command": "mycli",
  "result": {
    "description": "Example agent-first CLI",
    "commands": [
      { "name": "runs list", "usage": "mycli runs list [--limit <n>]", "description": "List runs" },
      { "name": "runs get", "usage": "mycli runs get <run-id>", "description": "Get one run" }
    ]
  },
  "next_actions": [
    {
      "command": "mycli runs list [--limit <n>]",
      "description": "Start with recent runs",
      "params": { "n": { "default": 20 } }
    }
  ]
}
```

## Streaming (When Needed)

Use NDJSON only for temporal commands (`watch`, `follow`, `stream`).
Last event must be terminal `result` or `error` envelope.

```json
{"type":"start","command":"mycli runs watch abc123","ts":"2026-02-22T14:00:00Z"}
{"type":"step","name":"build","status":"started","ts":"2026-02-22T14:00:03Z"}
{"type":"step","name":"build","status":"completed","duration_ms":2050,"ts":"2026-02-22T14:00:05Z"}
{"type":"result","ok":true,"command":"mycli runs watch abc123","result":{"run_id":"abc123","status":"completed"},"next_actions":[]}
```

## Command Implementation Pattern

1. Define command with `Command.make`.
2. Execute domain logic.
3. Map output to success envelope.
4. Map failures to error envelope with `fix`.
5. Add contextual `next_actions`.
6. Register command under root.
7. Update root command tree output.
8. Add/adjust tests.

## Test Requirements

For every new or changed command, add tests for:
- success envelope shape
- error envelope shape (`error.code`, `fix`, `next_actions`)
- `next_actions` correctness and prefilled values
- truncation behavior for large outputs
- root command discoverability
- streaming terminal event correctness (if streaming command)

Run only changed tests unless user asks full suite.

## Anti-Patterns

- Plain text output
- Hidden commands requiring `--help` parsing
- Unbounded log/list dumps
- Error messages without machine codes
- Static next steps unrelated to command outcome
- Streaming without terminal `result` or `error`

## Quick Checklist

- [ ] JSON envelope only
- [ ] Root command returns command tree
- [ ] Context-safe truncation with full output pointer
- [ ] Actionable errors with `fix`
- [ ] Contextual `next_actions` templates + params
- [ ] Strict typing, no unsafe TypeScript shortcuts
- [ ] Tests added and passing
