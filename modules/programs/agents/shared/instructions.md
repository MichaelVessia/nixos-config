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
- dcg blocks `git worktree remove`. Use `worktree-gc <path>...` to remove
  linked worktrees. Remove a worktree that you created when its work is pushed.

# Issue Tracking

- When you start work on an issue, update its status to `In Progress`, or the
  equivalent status, in the appropriate issue tracker.

# Environment

- Prefer the repository's existing Nix environment. Do not mutate it without
  evidence that the missing dependency belongs to the project. Use
  `nix run nixpkgs#<package>` for one-off tools.
- Use the personal Executor's `t3_*` integrations for remote T3 control.
  Discover them with Executor's tool search. T3's native `t3-code` connection
  controls the current environment. Keep remote T3 authorization in Executor.

# Tool discovery

- If a needed tool is missing, search the connected Executor instances before
  reporting it unavailable or asking the user to supply data or connect a service.
  Check both `executor` and `executor-flosports` when available.
- Read each instance's `execute` instructions. Search by service and task, inspect
  the matching tool's schema, and use the tool within the user's authorized scope.
- A missing tool or authentication failure in one instance does not establish
  that another instance lacks access. Distinguish a missing tool from an
  authentication or permission failure. Report the specific blocker after checking
  the available instances.

# Testing

- Use focused checks for changed behavior and regression tests for reproducible
  bugs. Documentation edits need content and link checks, not system builds.
- Complete the requested work and relevant verification. Fix failures caused by
  the change and rerun affected checks. Stop when checks pass or a specific
  blocker prevents completion. CI runs the full suite.

# Delegation

- Workers default to Claude Opus 5.5. Use low effort for simple tasks, medium
  for normal tasks, and high for complex or risky tasks. Workers report observed
  findings and proof. The implementation owner applies fixes.
- Give each worker a goal, relevant context, scope, and completion condition.
  Keep computer use within the user's request. Explicit task instructions for
  provider, model, or reasoning take precedence.

# t3-pstack

- t3-pstack is pinned by Nix. Use the installed upstream skills. Manage the pin
  and local rules in nixos-config. Do not install a second copy from npm.
- Read ~/.config/t3-pstack/models.md before delegation. All roles inherit the
  session model and effort, including panels. These choices override skill
  defaults and mixed-model recommendations. Discover live T3 capabilities.
- Subagents do read-only work on the session model. Give file-writing work to
  a separate worker. Explicit task instructions take precedence.
- Use the current runtime's tools and paths. Use T3 preview tools for browser
  work. Search connected Executors for missing service tools.
- Use GitHub and gh for PRs. Do not select Origin or Graphite from skill defaults.
- Keep the requested outcome separate from PR milestones. A request to complete
  work authorizes its remaining steps. Do not require another go after planning
  or stop at one PR while agreed work remains. Planning-only requests stop at
  the plan. Merge only with authorization.
- Before PR handoff, check the final diff, base, title, and description. Update
  stale metadata. Register every worked PR with T3, including each stack layer,
  and verify registration before finishing.
- When asked to monitor or get PRs merge-ready, use native T3 PR watches. Keep
  one monitoring owner and confirm ownership when transferring work. Do not run
  a polling script or watcher subagent when native watches are available.
  Delegated children return PR URLs and pending checks to the parent.
- Opening a PR alone does not authorize indefinite monitoring. An agreed request
  to finish a migration or make its PRs merge-ready does not need a babysit keyword.

# Obsidian Vault

- Use `~/vaults/brain` for reviewed general knowledge shared across work and
  personal devices. Do not put work details or private information there.
- Use `~/vaults/flosports` for work context. It is shared only between flomac
  and foundry. Use `~/vaults/private` for personal context on personal devices.
- Read the selected vault's `AGENTS.md` before writing. If the vault is absent,
  do not substitute another vault or create a private vault on a work device.
- Choose the vault by content, not the current computer or repository. If the
  destination is ambiguous or the note mixes categories, ask the user and wait
  before creating or updating any note. Do not save to a default vault first.
- If a requested brain note contains work or private details, ask what to remove
  or which restricted vault to use before saving.
- Update the appropriate vault when work reveals durable context, decisions,
  people context, or reusable notes. Keep uncertain notes in the restricted
  vault until the user reviews them.
