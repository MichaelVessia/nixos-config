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

# Environment

- Prefer the repository's existing Nix environment. Do not mutate it without
  evidence that the missing dependency belongs to the project. Use
  `nix run nixpkgs#<package>` for one-off tools.

# Testing

- Cover new observable contracts. Every bug fix needs a regression test.
- Run focused validation locally. CI runs the full suite.
- Test behavior, not implementation details.

# Obsidian Vault

- Treat `/Users/michael.vessia/obsidian` as shared durable memory for agent
  work, regardless of the repository or working directory.
- Update the vault when work reveals durable project context, decisions, people
  context, or reusable notes that future agents should inherit.
- Before editing the vault, read `/Users/michael.vessia/obsidian/AGENTS.md`.
