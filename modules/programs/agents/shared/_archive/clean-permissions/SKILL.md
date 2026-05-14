---
name: clean-permissions
description: Clean up Claude Code permissions allowlist
---

Analyze and clean up Claude Code permissions for this project.

## Steps

1. Read the global base permissions from `~/.claude/settings.json`
2. Read the project-local permissions from `.claude/settings.local.json` (if it exists)
3. Analyze the project-local rules and:

   **Clean up:**
   - Remove rules already covered by global wildcards (e.g., `git log --oneline -3` covered by `git:*`)
   - Consolidate specific rules into wildcards where patterns emerge (e.g., multiple `npm run test:foo`, `npm run test:bar` → `npm run test:*`)
   - Remove exact duplicates
   - Remove rules with hardcoded paths that are no longer relevant (e.g., specific nix store paths)

   **Suggest promotions to global:**
   - Identify rules that seem generally useful (not project-specific)
   - Examples: common CLI tools, language runtimes, build tools
   - Exclude: rules with absolute paths, project-specific scripts, one-off commands

4. Present a summary:
   - Rules to remove (with reason)
   - Rules to consolidate (show before/after)
   - Suggestions for global promotion
   - Final cleaned project-local allowlist

5. Ask for confirmation before applying changes

6. If user approves:
   - Update `.claude/settings.local.json` with cleaned rules
   - Show the suggested additions for global settings (user must manually add these to their nix config)

## Notes

- Never remove `deny` rules without explicit confirmation
- Preserve any rules the user explicitly added (ask if unsure)
- The goal is minimal project-local config - let global handle common cases
