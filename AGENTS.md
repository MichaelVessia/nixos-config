# nixos-config

Personal NixOS, nix-darwin, Home Manager, and sops-nix configuration. Read the
source of truth instead of trusting summaries:

- Hosts: `nixosConfigurations` and `darwinConfigurations` in `flake.nix`, and
  `hosts/<name>/`.
- Setup, apply commands, secrets, and per-host notes: `README.md`.
- Dev shell tools: `devShells` in `flake.nix`. Hooks: `lefthook.yaml`.

## Rules

- Put configuration at the narrowest scope (`hosts/`, `users/`, `modules/`) and
  follow nearby patterns.
- Never activate a configuration (`reload`, `deploy`, `nh ... switch`,
  `*-rebuild switch`) unless the user asks. For remote hosts, use
  `deploy -s .#<host>` (README "Deploying to other hosts"). Add new hosts to
  `deploy.nodes` in `flake.nix` when they run sshd.
- Work on local master; no branches, worktrees, or PRs. Commit after checks.
  Preserve unrelated local edits.
- Keep `stateVersion` values. Do not hand-edit generated hardware files.
- `git add` new files; flakes ignore untracked files.

<important if="changing Nix files">
- `nix develop --command alejandra --check $(git ls-files '*.nix')`
- Do not run `nix eval`, `nix flake check`, or host builds. The user's
  `nh os switch` shows whether the change evaluates and builds.
- Flake input changes need the matching `flake.lock` update.
</important>

<important if="changing secrets">
- Follow `README.md` "Secrets Management". Run
  `./scripts/check-sops-encryption.sh` on changed files. Never print or commit
  decrypted values.
</important>

<important if="changing AI-agent tooling">
- Shared skills and instructions: `modules/programs/agents/shared/`, wired by
  `modules/programs/agents/shared.nix` (keep its per-skill symlinks).
- Validate changed JSON with `jq empty`.
</important>
