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

# Code Review

- When providing feedback or suggesting alternatives, include concrete code
  examples from the actual codebase rather than abstract descriptions.
- When reviewing PR feedback from GitHub Copilot or other reviewers, summarize
  all comments first, then address them systematically one by one with explicit
  file:line references.

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

# Debugging

- For auth errors (401, 403), check environment variables and secrets early
  (TOKEN_SECRET, API keys).

# Tooling & workflow

- AST-first where it helps. Prefer ast-grep for tree-safe edits when it is
  better than regex.

# Final Handoff

Before finishing a task:

- Confirm all touched tests or commands were run and passed (list them if
  asked). Summarize changes with file and line references.
- Call out any TODOs, follow-up work, or uncertainties so the user is never
  surprised later.
