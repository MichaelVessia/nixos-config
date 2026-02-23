# How to Ralph

Ralph now supports a `cruster`-style autonomous loop with a required focus prompt
and two agent variants:

- `./ralph/ralph-auto-claude.sh`
- `./ralph/ralph-auto-codex.sh`

## Prerequisites

- Agent CLI installed:
  - `claude` for Claude variant
  - `codex` for Codex variant
- `jq` installed
- `ralph/ralph-auto-claude.jsonc` configured
- `ralph/ralph-auto-codex.jsonc` configured
- Specs directory exists (default: `docs/prds`)

## Quick Start

```bash
# 1. Configure loop
$EDITOR ralph/ralph-auto-claude.jsonc
$EDITOR ralph/ralph-auto-codex.jsonc

# 2. Run Claude variant
./ralph/ralph-auto-claude.sh "implement authentication MVP"

# 3. Or run Codex variant
./ralph/ralph-auto-codex.sh "implement authentication MVP"
```

## Focus Mode

Focus prompt is required. Agent must:

1. Work only on the focus topic
2. Complete one task per iteration
3. Update specs as it works
4. Signal:
  - `TASK_COMPLETE: <summary>` for one completed task
  - `NOTHING_LEFT_TO_DO` when focus is complete

## Options

```bash
./ralph/ralph-auto-claude.sh "<focus>" [options]
./ralph/ralph-auto-codex.sh "<focus>" [options]
```

Supported options:

- `--config <path>`: alternate config file
- `--skip-checks`: skip CI checks
- `--max-iterations <n>`: stop after `n` iterations (`0` = unlimited)
- `--judge`: run judge pass when agent says `NOTHING_LEFT_TO_DO`
- `--judge-first`: judge before main loop

## Config File

`ralph/ralph-auto-claude.jsonc` and `ralph/ralph-auto-codex.jsonc` fields:

- `specsDir`: markdown specs directory
- `model`: agent model
- `variant`: agent variant/profile
- `commitPrefix`: git commit prefix
- `checks`: required post-task CI commands
- `commands` (optional): extra command reference for prompt

## CI Checks

Checks run after each `TASK_COMPLETE`.

- If checks pass: Ralph commits changes
- If checks fail: changes stay in working tree for next iteration

## Judge Mode

Judge mode validates completion when agent says `NOTHING_LEFT_TO_DO`:

- `MORE_WORK_TO_DO` resumes loop
- `ALL_WORK_DONE` exits loop

## Monitoring

```bash
# Tail loop log
tail -f .ralph-auto/ralph-auto.log

# Check recent automated commits
git log --oneline -5 --grep="Ralph-Auto"
```
