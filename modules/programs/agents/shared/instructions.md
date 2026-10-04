# Communication

- Reply to the user only in ASD-STE100 Simplified Technical English.
- Be extremely concise, but use correct grammar.
- Skip em dashes. Use commas, parentheses, or periods.

# Code

- Match the repository's existing naming, abstractions, comments, and validation
  practices. Prefer root-cause fixes and remove code made obsolete by the
  change.
- Prefer clean cutovers over backwards compatibility. Readability wins over old
  interfaces.

# Git

- Never use `--no-verify` to bypass commit hooks unless explicitly instructed.

# Issue Tracking

- When you start work on an issue, update its status to `In Progress`, or the
  equivalent status, in the appropriate issue tracker.

# Environment

- Prefer the repository's existing Nix environment. Do not mutate it without
  evidence that the missing dependency belongs to the project. Use
  `nix run nixpkgs#<package>` for one-off tools.

# Testing

- Use focused checks for changed behavior and regression tests for reproducible
  bugs. Documentation edits need content and link checks, not system builds.
- Complete the requested work and relevant verification. Fix failures caused by
  the change and rerun affected checks. Stop when checks pass or a specific
  blocker prevents completion. CI runs the full suite.

# Delegation

- In BB, all owner and dispatcher threads use Codex GPT-6.1-Sol at low
  reasoning. Owners organize work, check for duplicate tasks, supervise workers
  and required gates, and report results.
- Workers default to Claude Opus 5.5. Use low effort for simple tasks, medium
  for normal tasks, and high for complex or risky tasks. Workers report observed
  findings and proof. The implementation owner applies fixes.
- Give each worker a unique BB task thread and a goal, relevant context, scope,
  and completion condition. Keep computer use within the user's request.
  Explicit task instructions for provider, model, or reasoning take precedence.

# pstack

- pstack subagents: read-only work on your own model only. Give file-writing
  work to a separate worker, not a subagent.
- The installed skills use upstream Cursor tool names. Use the current
  runtime's equivalent tools. `Task` means a subagent, `AskQuestion` means
  a user question, and `create-skill` means the available skill authoring tool.
- If a runtime has no named pstack agent type, read the matching prompt in
  `~/.agents/pstack/agents/` and pass it to a generic subagent.
- Use the model rows in these instructions or the runtime's `pstack-models.md`.
  Manage changes through `modules/programs/agents/shared/pstack-models.md`
  in nixos-config. Do not create a Cursor rules file on another runtime.
- For transcript and project skill paths, use the current runtime's paths.
  Discover MCP servers from the available tools, not a Cursor `mcps/` directory.
- Use the available browser tools for `control-ui`. For recurring work,
  use the runtime's scheduler or a bounded polling loop. For PR checks,
  use pstack's Babysit playbook.

# Obsidian Vault

- Treat `/Users/michael.vessia/obsidian` as shared durable memory for agent
  work, regardless of the repository or working directory.
- Update the vault when work reveals durable project context, decisions, people
  context, or reusable notes that future agents should inherit.
- Before editing the vault, read `/Users/michael.vessia/obsidian/AGENTS.md`.
