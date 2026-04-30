---
name: update-pr-title
description: Set the current PR's title to the best-fitting conventional-commit title based on the actual changes. Flags when the choice was hard, since that often means the PR is doing too much.
allowed-tools: Bash(gh pr edit:*), Bash(gh pr view:*), Bash(gh pr diff:*)
model: claude-sonnet-4-6
---

## Context

- Current PR: !`gh pr view --json number,title,url,files,commits,baseRefName 2>/dev/null || echo "No PR found"`

## Your task

Pick the single best conventional-commit title for the current PR and apply it.

### 1. Gather evidence

- Commit messages and their existing prefixes (from the context above).
- File paths touched (to infer scope and surface area).
- If needed, run `gh pr diff` to inspect the actual changes.

### 2. Choose the type

Pick the type that describes the **dominant intent** of the PR. Do NOT default
to `feat`.

- `feat` — new user-facing functionality
- `fix` — bug fix
- `refactor` — restructuring without behavior change
- `perf` — performance improvement
- `docs` — documentation only
- `test` — adding or updating tests only
- `chore` — maintenance, dependency bumps, config
- `ci` — CI/CD pipeline changes
- `build` — build system / tooling
- `style` — formatting, whitespace, naming (no logic change)

Decision rules:
- If commits all share one prefix and it matches the diff, use it.
- If commits disagree, weight by what the user-visible effect is, not by file
  count. One small `feat` commit beats five `chore` commits if the feature is
  the point.
- A bug fix that also adds a regression test is still `fix`, not `test`.
- A refactor that incidentally fixes a bug is `fix` if the bug fix is the
  reason the PR exists, otherwise `refactor`.

### 3. Choose the scope

Use a concise scope only when it's obvious from the touched paths (e.g. one
package, module, or feature area). Skip the scope rather than invent one.

### 4. Assemble the title

- Format: `<type>(<scope>): <summary>` or `<type>: <summary>` if no scope.
- Imperative mood, lowercase except proper nouns, ≤72 chars.
- Summary describes the *intent*, not the mechanism.

### 5. Flag a difficult decision

If picking the type was genuinely hard, say so out loud before applying. The
decision counts as hard when any of these is true:

- Two or more types each describe a substantial fraction of the diff (e.g. a
  real feature *and* an unrelated refactor).
- Commits disagree and the diff doesn't clearly favor one.
- The PR touches multiple unrelated areas of the codebase.

In that case, output a short note like:

> **Heads up**: this PR is split between `feat` (auth provider) and `refactor`
> (logger cleanup). Consider splitting into two PRs. Picking `feat` since the
> auth work is the stated goal.

Then proceed with the chosen title. Do not block on this — the user can split
the PR themselves if they agree.

### 6. Apply

```
gh pr edit --title "<chosen title>"
```

Report the new title and (if flagged) the scope concern.
