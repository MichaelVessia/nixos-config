---
name: init-lefthook
description: Set up lefthook with standard pre-commit hooks
---

# Initialize Lefthook

Set up lefthook with standard pre-commit checks for this project.

## Steps

1. **Detect environment**:
   - Package manager from lock file (bun.lock/pnpm-lock.yaml/package-lock.json)
   - Nix project: check for `flake.nix` (if yes, ask if hooks should use `nix develop -c`)
   - Beads: check for `.beads/` directory

2. **Install lefthook**:
   ```bash
   [bun/pnpm/npm] add -D lefthook
   ```

3. **Create `lefthook.yml`**:

   **Standard (with beads):**
   ```yaml
   pre-commit:
     commands:
       beads-sync:
         run: |
           if command -v bd >/dev/null 2>&1 && [ -d .beads ]; then
             bd sync --flush-only >/dev/null 2>&1 || echo "Warning: bd sync failed"
             git add .beads/issues.jsonl 2>/dev/null || true
           fi
         priority: 1
       format-fix:
         glob: "*.{ts,tsx,mjs,js,jsx}"
         run: bunx oxfmt {staged_files}
         stage_fixed: true
         priority: 2
       lint-fix:
         glob: "*.{ts,tsx,mjs,js,jsx}"
         run: bunx oxlint --fix {staged_files}
         stage_fixed: true
         priority: 3
       typecheck:
         run: bun run typecheck
         priority: 4
       test:
         run: bun run test
         priority: 4

   post-merge:
     commands:
       beads-prime:
         run: |
           if command -v bd >/dev/null 2>&1 && [ -d .beads ]; then
             bd prime >/dev/null 2>&1 || true
           fi
       install-deps:
         run: bun install
   ```

   **Without beads:** Omit beads-sync, beads-prime commands.

   **With nix develop:** Prefix commands with `nix develop -c` or `nix develop --command`:
   - `run: nix develop -c bunx oxfmt {staged_files}`
   - `run: nix develop -c bun run typecheck`

4. **Run lefthook install**:
   ```bash
   [bunx/npx/pnpm] lefthook install
   ```

5. **Add to .gitignore** (if not present):
   ```
   .lefthook-local.yml
   ```

6. **Summary**: List created files and note that hooks are active.

## Notes

- If project doesn't have `typecheck` or `test` scripts, omit those hooks
- Ask for confirmation before creating lefthook.yml if one already exists
