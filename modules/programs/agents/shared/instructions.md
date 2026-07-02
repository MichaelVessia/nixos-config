# Communication

- Be extremely concise. Sacrifice grammar for concision.
- When planning, ask unresolved questions before starting work.
- Punctuation preference: Skip em dashes; reach for commas, parentheses, or
  periods instead.

# Code Quality & Processes

- Make small changes that compile and pass tests.
- Never disable tests, fix them.
- Never commit code that doesn't compile unless explicitly instructed.
- **Never compromise type safety**: No `any`, no non-null assertion operator
  (`!`), no type assertions (`as Type`).
- **Abstractions**: Consciously constrained, pragmatically parameterised,
  doggedly documented.
- No breadcrumbs. If you delete or move code, do not leave a comment in the old
  place. No "// moved to X", no "relocated". Just remove it.
- Instead of applying a bandaid, fix things from first principles, find the
  source and fix it versus applying a cheap bandaid on top.
- Clean up unused code ruthlessly. If a function no longer needs a parameter or
  a helper is dead, delete it and update the callers instead of letting the junk
  linger.

# Git

- Never use `--no-verify` to bypass commit hooks unless explicitly instructed.

# Environment

- I use Nix locally. If the environment fails, add or update flake.nix (and
  flake.lock if missing), expose devShells.default. Do not run nix commands
  yourself that change the environment. But if the user says you can run it you
  can.
- If it's a one-off missing program, use `nix run nixpkgs#<package>`.

# Design Philosophy

- No backwards compatibility. Simplest change > migration-friendly code.
  Readability > old interfaces.

# Testing Philosophy

- Test EVERYTHING. Tests must be rigorous. Our intent is ensuring a new person
  contributing to the same code base cannot break our stuff and that nothing
  slips by. We love rigour.
- Unless the user asks otherwise, run only the tests you added or modified
  instead of the entire suite to avoid wasting time.
- If you are ever curious how to run tests or what we test, read through
  .github/workflows; CI runs everything there and it should behave the same
  locally.
- Every bug fix must come with a regression test.
- Test behavior, not implementation details.

# Tooling & workflow

- AST-first where it helps. Prefer ast-grep for tree-safe edits when it is
  better than regex.

# Obsidian Vault

- Treat `/Users/michael.vessia/obsidian` as shared durable memory for agent
  work, regardless of the repository or working directory.
- Update the vault when work reveals durable project context, decisions, people
  context, or reusable notes that future agents should inherit.
- Before editing the vault, read `/Users/michael.vessia/obsidian/AGENTS.md`.

# Picking models for subagents and delegated work

Rankings (higher = better; cost = what I actually pay, not list price;
intelligence = how hard a problem it handles unsupervised; taste = UI/UX, code
quality, API design, copy):

| model      | reach via            | cost | intelligence | taste |
|------------|----------------------|------|--------------|-------|
| gpt-5.5    | Codex plugin         | 9    | 8            | 5     |
| sonnet-4.6 | Agent/Workflow model | 5    | 5            | 7     |
| opus-4.8   | Agent/Workflow model | 4    | 7            | 8     |
| fable-5    | Agent/Workflow model | 2    | 9            | 9     |

How to apply:

- Bulk/mechanical (clear-spec impl, data analysis, migrations, investigation):
  gpt-5.5.
- User-facing (UI, copy, API design) needs taste >= 7: fable-5 or opus-4.8.
- No strong signal: opus-4.8 for coding, gpt-5.5 for bulk, fable-5 for
  taste-critical.
- Cost is a tie-breaker only. When axes conflict for anything that ships:
  intelligence > taste > cost.
- Reviews: fable-5 or opus-4.8; a Codex review is a strong independent second
  lens. Review with a different model than wrote the code. Never use Haiku.
- Defaults, not limits. If a cheaper model's output misses the bar, redo on a
  smarter one without asking.

Reaching gpt-5.5 goes through the Codex plugin, not raw `codex exec` or the
internal `codex-*` skills (those are `user-invocable: false` helpers of the
rescue agent):

- Delegate a task (impl, fix, diagnosis, research): spawn the
  `codex:codex-rescue` agent via the Agent tool
  (`subagent_type: "codex:codex-rescue"`), passing `--model` / `--effort
  <none|minimal|low|medium|high|xhigh>` in the request. This is the maintained
  codex wrapper; do not hand-roll `codex exec`.
- Code review: `/codex:review`, or `/codex:adversarial-review` to challenge the
  approach. These are user-run slash commands (the agent cannot self-invoke
  them), so ask me to run one when a Codex review would help.
- Claude models (sonnet-4.6, opus-4.8, fable-5) run via the Agent/Workflow
  `model` parameter.

# Final Handoff

Before finishing a task:

- Confirm all touched tests or commands were run and passed (list them if
  asked). Summarize changes with file and line references.
- Call out any TODOs, follow-up work, or uncertainties so the user is never
  surprised later.
