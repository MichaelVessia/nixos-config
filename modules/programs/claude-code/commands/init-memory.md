---
description: Set up AGENTS.md and symlink CLAUDE.md to it
---

# Initialize Agent Memory

Create an AGENTS.md file for this repository and symlink CLAUDE.md to it.

## Steps

1. **Check existing files**:
   ```bash
   ls -la AGENTS.md CLAUDE.md 2>/dev/null; file AGENTS.md CLAUDE.md 2>/dev/null | grep -i link
   ```

2. **Explore the codebase** to understand:
   - Tech stack (check package.json, Cargo.toml, go.mod, etc.)
   - Project structure (key directories)
   - Build/test commands
   - Any existing documentation

3. **Create AGENTS.md** with these sections:

```markdown
# Project Name

Brief description of what this project does.

## Tech Stack

- Language/runtime
- Key frameworks/libraries
- Database (if any)

## Project Structure

```
src/           # Source code
tests/         # Test files
...
```

## Commands

```bash
# Install dependencies
<package-manager> install

# Run dev server
<command>

# Run tests
<command>

# Build
<command>
```

## Architecture Notes

Key patterns, conventions, or decisions worth knowing.
```

4. **Create symlink**:
   ```bash
   ln -s AGENTS.md CLAUDE.md
   ```

## Best Practices (from humanlayer.dev)

- **Keep it lean**: Under 300 lines. Agents can follow ~150-200 instructions reliably.
- **Universal only**: Only include what applies to every task. No task-specific guidance.
- **Pointers not copies**: Reference other docs (e.g., `See docs/architecture.md`) instead of embedding.
- **No style rules**: Don't use agents as linters. Use formatters/hooks instead.
- **Three pillars**: WHAT (tech stack, structure), WHY (purpose), HOW (commands, workflow).

Ask clarifying questions about the project before writing AGENTS.md.
