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
- Never activate a configuration (`reload`, `nh ... switch`,
  `*-rebuild switch`) unless the user asks. Validate instead.
- Work on local master; no branches, worktrees, or PRs. Commit after checks.
  Preserve unrelated local edits.
- Keep `stateVersion` values. Do not hand-edit generated hardware files.
- `git add` new files before evaluating; flakes ignore untracked files.

<important if="changing Nix files">
- `nix develop --command alejandra --check $(git ls-files '*.nix')`
- `nix flake check --no-build`, then evaluate or build the affected host.
- Flake input changes need the matching `flake.lock` update. Flomac also
  deploys from `hosts/flomac/flake.nix`; keep it aligned (see `README.md`).
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
