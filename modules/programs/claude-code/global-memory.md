# Communication

- Be extremely concise. Sacrifice grammar for concision.
- When planning, list unresolved questions at the end.

# Code Quality

- Make small changes that compile and pass tests.
- Never disable tests—fix them.
- Never commit code that doesn't compile unless explicitly instructed.

# Git

- Never use `--no-verify` to bypass commit hooks unless explicitly instructed.

# Environment

- Missing program? Use `nix run nixpkgs#<package>`.

# Design Philosophy

- No backwards compatibility. Simplest change > migration-friendly code. Readability > old interfaces.
