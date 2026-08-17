# nixos-config

Personal declarative configuration for NixOS, nix-darwin, Home Manager, and
sops-nix. The flake configures `framework13`, `tts-pi`, `claude-casino`, and
`flomac`; most user programs are shared across hosts through Home Manager.

## Repository map

- `flake.nix` / `flake.lock`: root inputs and system outputs; `nix develop`
  provides Alejandra, Lefthook, sops, age, and ssh-to-age.
- `hosts/`: host-specific NixOS and nix-darwin configuration.
- `users/`: Home Manager entry points; they compose reusable modules.
- `modules/programs/`: shared user programs, shells, editors, and AI-agent
  tooling. `modules/desktop/` and `modules/hardware/` hold reusable system
  modules.
- `modules/secrets/`: sops-nix declarations. Encrypted values live in
  `secrets/`; setup and editing instructions live in `README.md`.
- `scripts/`: recursively discovered commands installed into `~/bin`; keep
  script basenames unique.

## Working rules

- Follow nearby module patterns and put configuration at the narrowest scope:
  host-specific in `hosts/`, user-specific in `users/`, reusable configuration
  in `modules/`.
- Preserve `system.stateVersion` and `home.stateVersion` unless an explicit
  migration requires changing them.
- Add new flake-referenced files to Git before evaluating; Git flakes ignore
  untracked files.
- Do not hand-edit generated hardware configuration or
  `modules/programs/garage-bun.nix`; follow each file's regeneration notes.
- Never activate a configuration (`reload`, `nh ... switch`, or
  `*-rebuild switch`) unless the user explicitly asks. Validate by formatting,
  checking, evaluating, or building first.

<important if="changing Nix files">
- Run `nix develop --command alejandra --check $(git ls-files '*.nix')`.
- Run `nix flake check --no-build` and evaluate or build the affected host.
  Private SSH inputs require the user's existing GitHub authentication.
- Changes to a flake input must include its matching lockfile update.
</important>

<important if="changing flomac or flake inputs">
- Shell tooling selects the root flake; the README documents
  `hosts/flomac/flake.nix` and its lockfile as the flomac deployment entry point.
  Keep shared inputs and module arguments aligned, and validate both when a
  change affects both definitions.
</important>

<important if="changing secrets">
- Never commit plaintext credentials anywhere. Edit encrypted YAML with `sops`,
  update the matching declaration in `modules/secrets/`, and run
  `./scripts/check-sops-encryption.sh` on changed secret files.
- Do not print decrypted values or include them in diffs, logs, or responses.
</important>

<important if="changing AI-agent tooling">
- Shared agent instructions and skills live under
  `modules/programs/agents/shared/`; tool-specific configuration lives beside
  each tool under `modules/programs/agents/`.
- Pi's tracked `settings.json` and `settings-extensions.json` are intentionally
  writable through out-of-store symlinks. Validate changed JSON with `jq empty`.
- Preserve the per-skill symlink layout in `modules/programs/agents/shared.nix`;
  it intentionally leaves externally installed sibling skills untouched.
</important>
