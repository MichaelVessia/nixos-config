---
description: Set up Ralph autonomous agent structure in a repository
---

# Initialize Ralph

Set up the plans/ directory structure for Ralph autonomous agent workflows.

## Steps

1. **Create plans directory**:
   ```bash
   mkdir -p plans
   ```

2. **Add plans/ to .gitignore** (if not already present):
   - Read `.gitignore` if it exists
   - Add `plans/` entry if missing
   - Create `.gitignore` with `plans/` if file doesn't exist

3. **Verify setup**:
   ```bash
   ls -la plans/
   ```

4. **Summary**: Confirm plans/ directory created and gitignored. Mention user can now use `/ralph-prep` to generate prd.json files for Ralph runs.
