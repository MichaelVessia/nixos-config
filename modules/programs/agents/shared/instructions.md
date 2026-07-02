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

# Picking models for workflows and subagents

Rankings, higher = better. Starting point (adapted from Theo/t3.gg), tune to
taste. Cost reflects what I actually pay, not list price. Intelligence is how
hard a problem I can hand the model unsupervised. Taste covers UI/UX, code
quality, API design, and copy.

| model      | cost | intelligence | taste |
|------------|------|--------------|-------|
| gpt-5.5    | 9    | 8            | 5     |
| sonnet-4.6 | 5    | 5            | 7     |
| opus-4.8   | 4    | 7            | 8     |
| fable-5    | 2    | 9            | 9     |

How to apply:

- Defaults, not limits. Standing permission to override: if a cheaper model's
  output misses the bar, rerun or redo with a smarter model without asking.
  Judge the output, not the price tag. Escalating costs less than shipping
  mediocre work.
- No strong signal? opus-4.8 for coding, gpt-5.5 for bulk, fable-5 for
  taste-critical work.
- Cost is a tie-breaker only. When axes conflict for anything that ships,
  intelligence > taste > cost.
- Match reasoning effort to the work, not just the model. Claude Agent/Workflow
  calls take `effort: low|medium|high|xhigh|max`; Codex takes
  `model_reasoning_effort`. Mechanical/bulk -> low; hardest verify/judge/design
  -> high+. My codex default is xhigh (slow), so drop it with
  `-c model_reasoning_effort=low` for grep-and-summarize work.
- Bulk/mechanical work (clear-spec implementation, data analysis, migrations):
  gpt-5.5.
- Anything user-facing (UI, copy, API design) needs taste >= 7.
- Reviews of plans/implementations: fable-5 or opus-4.8, optionally gpt-5.5 as
  an extra independent perspective.
- Review with a different model than wrote the code; for high-stakes work get
  two independent lenses (e.g. fable-5 + gpt-5.5).
- Never use Haiku.
- Mechanics: gpt-5.5 is only reachable through the Codex CLI (`codex exec` /
  `codex review`; my ~/.codex/config.toml defaults to gpt-5.5 at xhigh). Use
  the `codex` agent type, or the codex skills (codex:codex-cli-runtime,
  codex:codex-result-handling, codex:gpt-5-4-prompting, codex:rescue). For work
  they don't cover (investigation, data analysis), run `codex exec -s
  read-only` directly with a self-contained prompt. Use `-s read-only` for
  investigation, `-s workspace-write` when it needs to edit files.
- Claude models (sonnet-4.6, opus-4.8, fable-5) run via the Agent/Workflow
  model parameter.

Using gpt-5.5 inside workflows and subagents (the model parameter only takes
Claude models, so use a wrapper):

- Spawn a thin Claude wrapper agent with `model: 'sonnet', effort: 'low'` whose
  prompt tells it to write a self-contained codex prompt, run `codex exec` via
  Bash, and return the result verbatim.

# Final Handoff

Before finishing a task:

- Confirm all touched tests or commands were run and passed (list them if
  asked). Summarize changes with file and line references.
- Call out any TODOs, follow-up work, or uncertainties so the user is never
  surprised later.
