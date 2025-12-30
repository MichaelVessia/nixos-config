---
allowed-tools: Read, Edit, Bash(git:*), Bash(cargo:*), Bash(npm:*), Bash(bun:*), Bash(pnpm:*), Bash(yarn:*), Bash(pytest:*), AskUserQuestion
description: Cut a release (bump version, commit, tag, push)
---

## Arguments

`$ARGUMENTS` - Optional: version specifier (`patch`, `minor`, `major`, or explicit `X.Y.Z`)

## Flags

Parse from `$ARGUMENTS`:
- `--dry-run`: Show what would happen without making changes
- `--no-push`: Commit and tag locally, don't push
- `--force`: Skip branch check
- `--yes`: Non-interactive mode (skip prompts)

## Process

### 1. Find Git Root

```bash
git rev-parse --show-toplevel
```

Error if not in a git repo. All operations happen from git root.

### 2. Detect Version File

Check in order (first match wins):
- `package.json` → `.version`
- `Cargo.toml` → `[package].version`
- `pyproject.toml` → `[project].version` or `[tool.poetry].version`
- `version.txt` → entire content (strict: exactly X.Y.Z)
- `VERSION` → entire content (strict: exactly X.Y.Z)

**Error if multiple found.** List them and abort.

### 3. Detect Package Manager (package.json only)

Check lockfiles:
- `bun.lockb` → bun
- `pnpm-lock.yaml` → pnpm
- `yarn.lock` → yarn
- `package-lock.json` → npm

**Error if multiple lockfiles.** Default to npm if none.

### 4. Pre-flight Checks

Abort if:
- Working tree dirty: "Uncommitted changes. Commit or stash first."
- Tag `vX.Y.Z` exists: "Tag vX.Y.Z already exists."
- Not on main/master: Warn and prompt (error if `--yes` without `--force`)
- Pre-release suffix in version: "Pre-release versions not supported."
- Multiple version files, lockfiles, or Python lockfiles

### 5. Determine Version

Parse current version (strict semver `MAJOR.MINOR.PATCH`):
- No arg or `patch`: increment PATCH
- `minor`: increment MINOR, reset PATCH
- `major`: increment MAJOR, reset MINOR and PATCH
- Explicit `X.Y.Z`: validate greater than current

### 6. Run Pre-release Checks

**Hard abort if checks fail.**

| Project | Command |
|---------|---------|
| package.json | `<pm> run check` or `<pm> run test` (first found) |
| Cargo.toml | `cargo test` |
| pyproject.toml | `pytest` |

### 7. Update Version

Edit version file with new version.

### 8. Commit, Tag, Push

```bash
git add <version-file> [<lockfile-if-changed>]
git commit -m "chore: release vX.Y.Z"
git tag vX.Y.Z
git push && git push --tags
```

Skip push if `--no-push`. Use default remote for current branch.

### 9. Output

```
Released vX.Y.Z
  Commit: <hash>
  Tag: vX.Y.Z
  Previous: vX.Y.Z
```

## Dry Run

If `--dry-run`, show:
- Version change: `0.1.0 → 0.2.0`
- Files to modify
- Commands that would run
- Then exit without changes

## Error Recovery

If push succeeds but tag push fails:
```
Error: Failed to push tags.
The commit was pushed but the tag was not.
To recover manually:
  git push --tags
```

## Lockfiles to Include

| Project | Lockfile |
|---------|----------|
| package.json | Detected lockfile (error if multiple) |
| Cargo.toml | Cargo.lock |
| pyproject.toml | poetry.lock, pdm.lock, or uv.lock (error if multiple) |

Don't run install/lock commands - just commit if changed.

## Not Supported

- Monorepos/workspaces
- Pre-release versions (1.0.0-beta.1)
- Custom commit messages
- GitHub Releases
- flake.nix
