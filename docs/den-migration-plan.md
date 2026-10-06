# Migration plan: nixos-config to den

Status: proposal, not started. Written 2026-09-25 against den `main`
(commit `f88d635`, 2026-09-24) and this repository at `944062f`.

This document is the complete plan to move the repository from a hand-wired
flake to [den](https://github.com/denful/den). It covers every host, user,
module, script, document, and agent instruction in the repository. Each phase
ends in a state that evaluates, builds, and can be deployed. No phase requires
the next one.

Read `docs/den-migration-plan.md` before any migration work. Read the den docs
listed in [References](#references) before writing an aspect.

---

## 1. Goals, non-goals, decisions

### Goals

1. Every host, user, and home is a den entity. Den generates
   `nixosConfigurations`, `darwinConfigurations`, and `images`.
2. Every feature is one aspect that holds its system half and its home half.
3. No `specialArgs` plumbing. `username`, `enableHomelabSkills`, and
   `pkgs-unstable` disappear as module arguments.
4. Platform guards (`isLinux`, `isDarwin`) exist only where one aspect serves
   both platforms. A Linux-only feature is included only by Linux hosts.
5. One flake, one lockfile, one deployment entry point for all hosts.
6. Zero behavior change at each phase boundary. The system closure of each
   host is byte-identical to the baseline until a phase says otherwise.
7. Docs, scripts, and agent guidance describe the new layout on the day the
   layout changes, in the same commit.

### Non-goals

- Standalone Home Manager (`den.homes`). All users stay host-managed.
- hjem, nix-maid, WSL, MicroVM, fleets, namespaces, angle-bracket syntax.
- flake-file. `flake.nix` stays hand-written.
- Changing `system.stateVersion`, `home.stateVersion`, or secrets content.
- Rewriting the bodies of large leaf modules (niri keybinds, zellij config,
  claude-code settings). Bodies move; they do not change.

### Decisions the owner must confirm before Phase 1

| ID | Decision | Recommendation | Why |
|----|----------|----------------|-----|
| D1 | Root flake and `hosts/flomac/flake.nix` | Consolidate into the root flake. Delete `hosts/flomac/flake.nix` and its lockfile. | The flomac flake was created to isolate the private `floai` input (commit `f6c0145`). The root flake has carried `floai` since `92f5537`, so the isolation no longer exists. The two input sets have drifted (`bun2nix` only in flomac; `dgop`, `dms`, `fmcal`, `grok-bot`, `paperless-cli` only in root). One flake removes the drift and the "keep both aligned" rule. |
| D2 | den pin | `github:denful/den/latest` | `latest` moves only on releases. `main` moves on every merged PR and carries heads-up changes. Update den on purpose, with its lockfile. |
| D3 | Module system for the flake | flake-parts | `perSystem` gives the dev shell and the nh helper packages without custom merge options. den is a flake-parts module. |
| D4 | Where leaf module bodies live | Fold each leaf module into an aspect file at the same path. | Out-of-store symlinks (Pi, OMP, OpenCode, Zed) and the DMS snapshot script name `modules/programs/...` paths. Folding in place keeps every one of those paths valid and needs no doc rewrite for data files. |
| D5 | Unstable packages | Overlay `pkgs.unstable` from `inputs.nixpkgs-unstable.legacyPackages` | Same package set as today (`legacyPackages`, no extra config). `home-manager.useGlobalPkgs = true` makes it visible to Home Manager without a second definition. |
| D6 | Marker for not-yet-migrated files | `_` prefix on the file name | import-tree ignores any path component that starts with `_`. `git ls-files 'modules/**/_*.nix'` lists remaining work. When the list is empty, the migration is done. |

If D1 is rejected, see [Appendix C](#appendix-c-keeping-a-separate-flomac-flake).

---

## 2. Target architecture

### 2.1 Repository layout

```
flake.nix                 hand-written: inputs + flake-parts mkFlake + import-tree ./modules
flake.lock
modules/                  every .nix file here is a den/flake-parts module (import-tree)
  den.nix                 imports inputs.den.flakeModule; den.default; den.schema
  nixpkgs.nix             pkgs.unstable overlay; allowUnfree; shared nix.settings
  home-manager.nix        Home Manager host settings (useGlobalPkgs, backups)
  dev-shell.nix           perSystem devShells.default (alejandra, lefthook, sops, age, ssh-to-age)
  nh.nix                  perSystem packages from den.lib.nh (optional, Phase 8)
  images.nix              flake.images.tts-pi
  hosts/
    framework13.nix       den.hosts + den.aspects.framework13
    claude-casino.nix
    tts-pi.nix
    flomac.nix
  users/
    michaelvessia.nix     den.aspects.michaelvessia
    michael.vessia.nix    den.aspects."michael.vessia"
    cc.nix                den.aspects.cc
    pi.nix                den.aspects.pi
  programs/               feature aspects, one concern per file (folded in place)
    agents/ ...           data files (json, yml, md, skills) stay beside their aspect
    dms/config/ ...       snapshot data stays here (dms-config-save writes here)
    nvf/ ...
  desktop/niri.nix        den.aspects.niri (system half + provides.to-users home half)
  hardware/printing.nix   den.aspects.printing
  secrets/                den.aspects.sops-<host>
pkgs/                     callPackage expressions; NOT scanned by import-tree
  linear-cli.nix
  pup.nix
  rootly.nix
hosts/                    generated and static host artifacts; NOT scanned
  framework13/hardware-configuration.nix
  framework13/certs/caddy-local-root.crt
  claude-casino/hardware-configuration.nix
  tts-pi/README.md
scripts/                  unchanged (installed to ~/bin by an aspect)
secrets/                  unchanged (encrypted YAML)
docs/                     this plan, initial-setup.md
```

`users/` at the top level is deleted. `hosts/*/default.nix` files are deleted.
`modules/programs/default.nix`, `modules/programs/agents/default.nix`,
`modules/programs/browsers/default.nix`, `modules/desktop/default.nix`, and
`modules/programs/nvf/default.nix` (import lists) are deleted; inclusion
becomes `includes = [ ... ]` on aspects.

### 2.2 Entities

```nix
# modules/hosts/*.nix each declare their own host. Shown together here.
den.hosts.x86_64-linux.framework13.users.michaelvessia = { };
den.hosts.x86_64-linux.claude-casino.users.cc = { };
den.hosts.aarch64-linux.tts-pi.users.pi.classes = [ "user" ];   # no Home Manager
den.hosts.aarch64-darwin.flomac.users."michael.vessia" = { };

# modules/den.nix
den.schema.user.classes = lib.mkDefault [ "user" "homeManager" ];
```

`user` stays in the default class list so the `user` class (forwarded to
`users.users.<name>`) keeps working next to Home Manager. `tts-pi` overrides
the list to disable Home Manager, which also removes the Home Manager module
from its closure.

Host schema gains one option:

```nix
den.schema.host = { lib, ... }: {
  options.homelab = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Host has access to the homelab network; enables homelab skills and CLIs.";
  };
};
den.hosts.x86_64-linux.framework13.homelab = true;
```

This replaces the `enableHomelabSkills` special argument.

### 2.3 Aspect catalog (end state)

Feature aspects. Each name is `den.aspects.<name>`. "Classes" lists the class
keys the aspect writes. "Included by" lists the entities or aspects that include
it. Source files are today's paths.

| Aspect | Classes | Included by | Source today |
|--------|---------|-------------|--------------|
| `cli-base` | homeManager | all three HM users | `modules/programs/common.nix` (packages), `users/common.nix` (scripts to `~/bin`, sessionPath) |
| `shell` | homeManager | cli-base | `modules/programs/shell.nix` |
| `git` | homeManager | cli-base | `modules/programs/git.nix` |
| `ssh` | homeManager | cli-base | `modules/programs/ssh.nix` |
| `zellij` | homeManager | cli-base | `modules/programs/zellij.nix` |
| `nvf` | homeManager | cli-base | `modules/programs/nvf/*.nix` (17 files, each contributes to `den.aspects.nvf.homeManager`) |
| `stack` | homeManager | cli-base | `modules/programs/stack.nix` |
| `worktrunk` | homeManager (imports worktrunk HM module) | cli-base | `modules/programs/worktrunk.nix` + `sharedModules` entry in `flake.nix` |
| `agents` | homeManager (declares `agentHarnesses.executor.url`) | michaelvessia, michael.vessia, cc | `modules/programs/agents/default.nix` |
| `agents.skills` | homeManager (reads `host.homelab`) | agents | `modules/programs/agents/shared.nix` |
| `agents.claude-code` | homeManager | agents | `modules/programs/agents/claude-code/default.nix` |
| `agents.codex` | homeManager | agents | `modules/programs/agents/codex.nix` |
| `agents.pi` | homeManager | agents | `modules/programs/agents/pi/default.nix` |
| `agents.omp` | homeManager | agents | `modules/programs/agents/omp/default.nix` |
| `agents.opencode` | homeManager | agents | `modules/programs/agents/opencode.nix` |
| `agents.collie`, `agents.agentsview`, `agents.plannotator` | homeManager | agents | the matching files |
| `herdr` | homeManager | cli-base | `modules/programs/herdr.nix` |
| `takopi` | homeManager | michaelvessia, cc | `modules/programs/takopi/default.nix` |
| `ghostty` | homeManager | desktop-linux, mac-desktop | `modules/programs/ghostty.nix` (Linux package half only in desktop-linux) |
| `zed` | homeManager | desktop-linux, mac-desktop | `modules/programs/zed/default.nix` |
| `media` | homeManager | desktop-linux, mac-desktop | `modules/programs/media.nix` |
| `browsers.brave` | homeManager | desktop-linux | `modules/programs/browsers/brave.nix` |
| `syncthing` | homeManager | desktop-linux | `modules/programs/syncthing.nix` |
| `transcribe` | homeManager | desktop-linux | `modules/programs/transcribe.nix` |
| `x-to-obsidian` | homeManager | desktop-linux | `modules/programs/x-to-obsidian.nix` |
| `dms` | homeManager | desktop-linux | `modules/programs/dms/default.nix` |
| `niri` | nixos, `provides.to-users.homeManager` | framework13 | `modules/desktop/niri.nix` + `modules/programs/niri.nix` + `sharedModules` entries for niri and dms in `flake.nix` |
| `desktop-linux` | includes only | michaelvessia | new bundle |
| `mac-desktop` | homeManager | michael.vessia | `karabiner.nix`, `hammerspoon.nix`, `raycast.nix`, `cmux.nix` as `provides.*` |
| `homelab-clis` | homeManager | users on hosts with `host.homelab` | `fmcal.nix`, `paperless-cli.nix`, `hass-cli.nix`, `kuma-cli.nix` |
| `work` | homeManager | michael.vessia | `floai.nix`, pup and rootly packages, flomac secrets consumer |
| `printing` | nixos | framework13 | `modules/hardware/printing.nix` |
| `audio` | nixos | framework13 | pipewire block and `analog-sink-watchdog` from `hosts/framework13/default.nix` |
| `docker` | nixos, `provides.to-users.user.extraGroups` | framework13, claude-casino | docker blocks in both host files |
| `tailscale` | nixos | framework13 (with subnet routes), claude-casino | tailscale blocks |
| `nh` | nixos (reads `user`) | framework13, claude-casino | `programs.nh` blocks |
| `nix-settings` | os | every host (schema include) | `nix.settings` blocks (experimental-features, substituters) |
| `unstable-packages` | os (overlay) | every host | `pkgs-unstable` special argument |
| `home-manager-settings` | nixos, darwin | every host with HM (`den.schema.hm-host.includes`) | the four repeated blocks in `flake.nix` and `hosts/flomac/flake.nix` |
| `sops-framework13` | nixos | framework13 | `modules/secrets/default.nix` |
| `sops-tts-pi` | nixos | tts-pi | `modules/secrets/tts-pi.nix` |
| `sops-flomac` | homeManager (imports sops HM module) | michael.vessia | `modules/secrets/flomac.nix` + `sharedModules` entry |
| `homebrew` | darwin | flomac | homebrew block in `hosts/flomac/default.nix` |
| `macos-defaults` | darwin | flomac | `system.defaults` block |
| `snapcast-tts` | nixos | tts-pi | snapserver, snapclient, tts scripts, firewall |
| `user-scripts` | homeManager | cli-base | `users/common.nix` scripts loop |

Host aspects (`den.aspects.framework13`, `claude-casino`, `tts-pi`, `flomac`)
hold only what is true of that one machine: boot loader, hostname extras,
hardware imports, time zone, locale, VM variant, host-specific hosts entries and
certificates. Everything reusable is an include.

User aspects (`den.aspects.michaelvessia`, `"michael.vessia"`, `cc`, `pi`) hold
identity (groups, SSH keys, shell) and the list of feature bundles.

### 2.4 den batteries in use

| Battery | Where | Replaces |
|---------|-------|----------|
| `den.batteries.hostname` | `den.default.includes` | `networking.hostName` in four host files |
| `den.batteries.define-user` | `den.default.includes` | `users.users.<name>` (name, home, isNormalUser) and `home.username`/`home.homeDirectory` in three `users/*/home.nix` files |
| `den.batteries.primary-user` | michaelvessia, michael.vessia, cc, pi | `wheel` and `networkmanager` groups; `system.primaryUser` on flomac |
| `den.batteries.user-shell "zsh"` | michaelvessia, michael.vessia, cc | `programs.zsh.enable` (system) + `users.users.<n>.shell = pkgs.zsh` |
| `den.batteries.unfree [...]` | not used | `nixpkgs.config.allowUnfree = true` stays global (all four hosts set it today) |
| `den.batteries.flake-scope` | not used | aspect files close over `inputs` (den docs option 1) |

`pi` on tts-pi keeps `wheel`, `audio`, `networkmanager` via `primary-user` plus
`user.extraGroups = [ "audio" ]`.

### 2.5 Conventions (also go into `AGENTS.md`)

1. One file, one aspect, named after the concern. A file may add to an existing
   aspect (`den.aspects.nvf.homeManager.programs.nvf.settings...`) when the
   concern is large; keep those files in a directory named after the aspect.
2. Class keys: `nixos`, `darwin`, `homeManager`, `user`, `os`. Use `os` for
   settings shared by NixOS and Darwin.
3. A host aspect never writes `homeManager`. Home content that every user on a
   host needs goes under `provides.to-users.homeManager` on the host aspect or
   on a feature aspect the host includes. A `homeManager` key on a host aspect
   lands nowhere and den prints no warning.
4. A user aspect never writes `nixos` or `darwin` directly (den issue #694).
   Use the `user` class for `users.users.<name>` and `provides.to-hosts` or
   `provides.<host>` for anything else on the host.
5. Flake inputs are used by closing over `inputs` in the module file. Class
   modules do not take `inputs` as an argument.
6. Flat-form class modules that take `host` or `user` must end with `...`.
7. Named aspects, never anonymous functions in `includes`.
8. Files prefixed `_` are not loaded. They are legacy leaves awaiting folding.
   Do not add new `_` files.
9. Generated files (`hardware-configuration.nix`) and package expressions
   (`pkgs/`) live outside `modules/`.

---

## 3. Verification method (used by every phase)

### 3.1 Baseline

Before Phase 1, on `master`:

```bash
mkdir -p .baseline
for h in framework13 claude-casino tts-pi; do
  nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" > ".baseline/$h.drv"
done
nix eval --raw ".#darwinConfigurations.flomac.config.system.build.toplevel.drvPath" > .baseline/flomac.drv
nix eval --raw ".#images.tts-pi.drvPath" > .baseline/tts-pi-image.drv
nix eval --raw "./hosts/flomac#darwinConfigurations.flomac.config.system.build.toplevel.drvPath" > .baseline/flomac-hostflake.drv
```

`.baseline/` is added to `.gitignore`. Darwin evaluation on Linux works for
`drvPath` because nothing in the config uses import-from-derivation. The flomac
host-flake baseline may differ from the root-flake baseline; that is the current
drift, and D1 resolves it.

### 3.2 Phase gate

Every phase must pass all of these before merge:

```bash
nix develop --command alejandra --check $(git ls-files '*.nix')
nix flake check --no-build
for h in framework13 claude-casino tts-pi; do
  test "$(nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath")" = "$(cat .baseline/$h.drv)" && echo "$h identical"
done
test "$(nix eval --raw ".#darwinConfigurations.flomac.config.system.build.toplevel.drvPath")" = "$(cat .baseline/flomac.drv)" && echo "flomac identical"
test "$(nix eval --raw ".#images.tts-pi.drvPath")" = "$(cat .baseline/tts-pi-image.drv)" && echo "image identical"
```

When a phase intentionally changes a closure (the table in each phase says so),
run `nix build .#nixosConfigurations.<h>.config.system.build.toplevel` for old
and new and compare with `nix store diff-closures ./result-old ./result-new`.
Every difference must be explained in the phase's commit message. Then refresh
the baseline file for that host.

Expected differences that are acceptable and small:

- `define-user` sets `users.users.<n>.name` and `home` explicitly. NixOS
  already defaults these, so the closure should not change. If it does, the
  diff shows only the `users` JSON.
- `primary-user` adds `networkmanager` to `cc` on claude-casino. Keep the
  group list identical by not including `primary-user` on `cc` (use
  `user.extraGroups = [ "wheel" "docker" ]`) or accept the extra group.

### 3.3 Activation

Activation happens only when the owner runs it. After each phase that touches a
host, the owner runs on that host:

```bash
nh os build            # or: nh darwin build
nh os test             # NixOS only: activate without boot entry
reload                 # switch
```

For framework13 also boot the VM once after Phase 2 and Phase 4D:

```bash
nix build .#nixosConfigurations.framework13.config.system.build.vm
./result/bin/run-framework13-vm
```

For tts-pi: `nix build .#images.tts-pi` must succeed on framework13 (binfmt).
Deploy with `nixos-rebuild switch --flake ~/nixos-config#tts-pi --target-host pi@192.168.1.37` only after the image builds.

---

## 4. Phases

Phase order is fixed. Within Phase 4, the groups can be done in any order and by
different agents in parallel, one group per branch.

### Phase 0: prerequisites

Owner actions:

1. Confirm D1 to D6.
2. Capture the baseline (section 3.1). Commit `.gitignore` change.
3. Update `flake.lock` on `master` first if any input is stale, so baseline and
   migration share one input set.

Agent actions:

1. Create branch `den-migration`.
2. Add inputs and lock them. No other change in this commit.

```nix
den.url = "github:denful/den/latest";
import-tree.url = "github:denful/import-tree";
flake-parts = {
  url = "github:hercules-ci/flake-parts";
  inputs.nixpkgs-lib.follows = "nixpkgs";
};
```

Gate: `nix flake check --no-build` and identical closures (nothing uses the
new inputs yet).

### Phase 1: wiring cutover

This phase replaces `flake.nix` outputs, all four host files, all three
`users/*/home.nix` files, and `users/common.nix` with den entities and aspects.
Leaf module bodies are untouched. They are renamed with a `_` prefix so
import-tree skips them, and a bridge aspect per user imports them as before.

Closure change: none expected. Gate: identical closures for all four hosts and
the image.

#### 1.1 `flake.nix`

```nix
{
  description = "NixOS configuration";
  nixConfig = { ...unchanged... };
  inputs = { ...unchanged plus den, import-tree, flake-parts... };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
```

The `outputs` body shrinks from 165 lines to one. `forAllSystems`, `pkgs`,
`pkgs-unstable`, `specialArgs`, and the three `home-manager.*` blocks are
deleted.

#### 1.2 `modules/den.nix`

```nix
{ inputs, lib, den, ... }: {
  imports = [ inputs.den.flakeModule ];

  den.systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

  den.schema.user.classes = lib.mkDefault [ "user" "homeManager" ];

  den.schema.host = { lib, ... }: {
    options.homelab = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Host reaches the homelab network; enables homelab skills and CLIs.";
    };
  };

  den.default = {
    includes = [
      den.batteries.hostname
      den.batteries.define-user
    ];
    homeManager.home.stateVersion = "25.05";
  };
}
```

`system.stateVersion` stays per host (all are `25.05` on NixOS, `5` on flomac)
and is written in each host aspect, not in `den.default`. This keeps the
"preserve stateVersion" rule visible where it matters.

`den.systems` is set explicitly so `perSystem` outputs (dev shell) exist for the
same three systems as today's `forAllSystems` plus `aarch64-linux`. Today the
dev shell exists only for `x86_64-linux` and `aarch64-darwin`; adding
`aarch64-linux` is harmless.

#### 1.3 `modules/nixpkgs.nix`

```nix
{ inputs, den, ... }: {
  den.aspects.nix-settings.os = {
    nixpkgs.config.allowUnfree = true;
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
    };
  };

  den.aspects.unstable-packages.os.nixpkgs.overlays = [
    (final: _prev: {
      unstable = inputs.nixpkgs-unstable.legacyPackages.${final.stdenv.hostPlatform.system};
    })
  ];

  den.schema.host.includes = [
    den.aspects.nix-settings
    den.aspects.unstable-packages
  ];
}
```

Check before writing this: flomac sets `nix.enable = false` (Determinate Nix)
and today sets no `nix.settings`. nix-darwin does not write `nix.conf` in that
mode and may assert on some `nix.*` options. Keep flomac as it is: `nix.settings`
goes in `nixos` only, not `os`. Split the aspect: `nix-settings.nixos` for the nix daemon
settings, `nix-settings.os` for `allowUnfree`. framework13 additionally adds the
ghostty cachix substituter in its host aspect (today only framework13 has it).

#### 1.4 `modules/home-manager.nix`

```nix
{ inputs, den, ... }: {
  den.aspects.home-manager-settings = { host, ... }: {
    ${host.class}.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      # Transitional. Removed in Phase 4 when no `_` leaf remains.
      extraSpecialArgs = inputs // {
        inherit inputs;
        pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${host.system};
        enableHomelabSkills = host.homelab;
      };
    };
  };
  den.schema.hm-host.includes = [ den.aspects.home-manager-settings ];
}
```

`username` is the fourth special argument today. It is used only in
`hosts/flomac/default.nix` (moved into the flomac aspect in Phase 2) and
`flake.nix` (deleted). No leaf module uses it, so it is not carried.

`extraSpecialArgs` today is `inputs // specialArgs`, which exposes every input
by name (`x-to-obsidian.nix` takes `x-to-obsidian` as a module argument). The
transitional block reproduces that exactly.

#### 1.5 `modules/dev-shell.nix`

```nix
{
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [ alejandra lefthook sops age ssh-to-age ];
      shellHook = "lefthook install";
    };
  };
}
```

#### 1.6 `modules/images.nix`

```nix
{ config, ... }: {
  flake.images.tts-pi = config.flake.nixosConfigurations.tts-pi.config.system.build.sdImage;
}
```

flake-parts accepts arbitrary attributes under `flake`. `nix build
.#images.tts-pi` keeps working, so `hosts/tts-pi/README.md` needs no change.

#### 1.7 Host aspects with legacy bodies (transitional shape)

Phase 1 moves each host body into its aspect as one `nixos` module, verbatim.
Splitting into feature aspects is Phase 2. Example for framework13:

```nix
# modules/hosts/framework13.nix
{ inputs, den, ... }: {
  den.hosts.x86_64-linux.framework13 = {
    homelab = true;
    users.michaelvessia = { };
  };

  den.aspects.framework13 = {
    nixos = {
      imports = [
        ../../hosts/framework13/hardware-configuration.nix
        inputs.nixos-hardware.nixosModules.framework-12th-gen-intel
        inputs.sops-nix.nixosModules.sops
        ../secrets/_default.nix
        ../desktop/_niri.nix
        ../hardware/_printing.nix
      ];
      # ...verbatim body of hosts/framework13/default.nix minus its imports block...
    };
    provides.to-users.homeManager.imports = [
      inputs.niri.homeModules.niri
      inputs.dms.homeModules.dank-material-shell
      inputs.dms.homeModules.niri
      inputs.worktrunk.homeModules.default
    ];
  };
}
```

`networking.hostName` is deleted from the body because `hostname` battery sets
it. `users.users.michaelvessia = { isNormalUser; description; extraGroups;
shell }` stays verbatim in Phase 1 (define-user adds `name` and `home`, which
NixOS defaults to the same values). `programs.zsh.enable = true` stays.

tts-pi: the sd-image module and `raspberry-pi-3` module go into `nixos.imports`.
`users.users.pi` stays verbatim.

flomac: `hosts/flomac/default.nix` takes `username`. In Phase 1 the aspect is
`{ host, user, ... }` flat-form on `darwin` so `user.userName` replaces
`username` in the three places it appears (`brew trust` script,
`system.primaryUser`, `users.users.${username}`). This is the only body edit in
Phase 1. `hosts/flomac/flake.nix` and `hosts/flomac/flake.lock` are deleted
(D1). `scripts/nixos/upgrade` loses its host-flake branch in the same commit.

#### 1.8 User aspects with legacy bodies (transitional shape)

```nix
# modules/users/michaelvessia.nix
{ inputs, den, ... }: {
  den.aspects.michaelvessia.homeManager = { pkgs, ... }: {
    imports = [
      ../_users-common.nix        # was users/common.nix
      ../programs/_default.nix    # was modules/programs/default.nix
      ../programs/_niri.nix
    ];
    home.packages = [ inputs.grok-bot.packages.${pkgs.system}.default ];
  };
}
```

`home.username` and `home.homeDirectory` are dropped (define-user). Same shape
for `cc` (its nine imports) and `"michael.vessia"` (its three imports plus the
launchd agent, brew.env, and executor URL that live in `users/michael.vessia/home.nix`
today; those move verbatim into the aspect body).

`users/common.nix` moves to `modules/_users-common.nix` in Phase 1 and folds
into `den.aspects.user-scripts` in Phase 4A.

#### 1.9 Legacy leaf rename

Every `.nix` file under `modules/programs/`, `modules/desktop/`,
`modules/hardware/`, `modules/secrets/` gets a `_` prefix on its file name
(`git.nix` becomes `_git.nix`). Directories keep their names, so
`modules/programs/agents/pi/settings.json` and the other out-of-store targets
are unchanged. Import lists inside `_default.nix` files are updated to the new
names. The three `callPackage` expressions move to `pkgs/` now and their
`callPackage ./linear-cli {}` sites become `callPackage ../../pkgs/linear-cli.nix {}`.

Command sketch:

```bash
git ls-files 'modules/**/*.nix' | while read f; do git mv "$f" "$(dirname "$f")/_$(basename "$f")"; done
git mv modules/programs/_linear-cli pkgs/  # then flatten to pkgs/linear-cli.nix; same for pup, rootly
```

Then fix every `./x.nix` and `./dir` reference inside the renamed files.
`alejandra --check` and `nix flake check` catch missing ones. import-tree also
ignores a directory whose name starts with `_`, so `modules/programs/_nvf/`
would be an alternative; do not use it, because directory names must stay
stable for the data files.

#### 1.10 Docs in this commit

- `README.md`: "Applying Configuration" drops the flomac host-flake command
  and the paragraph about two lockfiles. "Directory Structure" gets the section
  2.1 tree. Add a short "How the flake is built" paragraph naming den and
  import-tree.
- `AGENTS.md` and `CLAUDE.md` (identical content; keep them identical): replace
  the repository map and the flomac rule. Add the den rules from section 2.5
  and the phase gate from section 3.2. Full text in [Appendix A](#appendix-a-agentsmd-after-migration).
- `scripts/nixos/upgrade`: remove the `HOST_FLAKE_DIR` branch.
- `modules/programs/_floai.nix` comment about `hosts/flomac/flake.nix`: delete the sentence.

Gate: section 3.2, all identical. Owner activates on framework13 and flomac.

### Phase 2: hosts

Split each host body into the feature aspects from section 2.3. One commit per
host. Closure change: none expected except where noted.

#### 2.1 framework13

| Today (`hosts/framework13/default.nix`) | Destination |
|---|---|
| `imports` hardware, nixos-hardware | `den.aspects.framework13.nixos.imports` |
| `boot.loader.*`, `boot.binfmt.emulatedSystems` | `framework13.nixos` |
| `networking.hostName` | deleted (hostname battery) |
| `networking.networkmanager.enable` | `framework13.nixos` (claude-casino and tts-pi also set it; keep per host, it is one line) |
| `networking.hosts`, `security.pki.certificateFiles`, `environment.sessionVariables` SSL vars | `framework13.nixos` (cert path becomes `../../hosts/framework13/certs/caddy-local-root.crt`) |
| `time.timeZone`, `i18n.*` | `den.aspects.locale-us-east.os`, included by framework13, claude-casino, tts-pi (all three set `America/New_York` and `en_US.UTF-8`; only framework13 sets `extraLocaleSettings`, which stays in its host aspect) |
| pipewire, rtkit, wireplumber rules, `analog-sink-watchdog`, `pavucontrol`, `alsa-utils` | `den.aspects.audio.nixos` (framework13-specific device names stay; the aspect is still only included by framework13, but it is a separable concern with its own comment block) |
| `hardware.bluetooth.*` | `framework13.nixos` |
| `users.users.michaelvessia` | deleted. `define-user` (name, home, isNormalUser), `primary-user` (wheel, networkmanager), `user-shell "zsh"` (shell), and `den.aspects.michaelvessia.user = { description = "Michael Vessia"; extraGroups = [ "input" ]; }`. `docker` and `ydotool` groups come from those aspects' `provides.to-users.user.extraGroups`. |
| `virtualisation.vmVariant` | `framework13.nixos` verbatim (it references `home-manager.users.michaelvessia`, which is valid NixOS-level config) |
| `programs.zsh.enable` | deleted (user-shell battery) |
| `nixpkgs.config.allowUnfree` | deleted (nix-settings aspect) |
| `nix.settings` | deleted except the ghostty cachix pair, which stays in `framework13.nixos.nix.settings` |
| `services.fwupd.enable` | `framework13.nixos` |
| `virtualisation.docker` | `den.aspects.docker = { nixos.virtualisation.docker = { enable = true; package = pkgs.docker_29; }; provides.to-users.user.extraGroups = [ "docker" ]; }` |
| `services.tailscale`, `tailscale-accept-routes` service | `den.aspects.tailscale.nixos.services.tailscale.enable`; `den.aspects.tailscale.provides.subnet-routes.nixos` holds `useRoutingFeatures` and the oneshot service; framework13 includes `den.aspects.tailscale.subnet-routes`, claude-casino includes `den.aspects.tailscale` |
| `programs.ydotool.enable` | `den.aspects.ydotool = { nixos.programs.ydotool.enable = true; provides.to-users.user.extraGroups = [ "ydotool" ]; }` |
| `programs.nh` | `den.aspects.nh.nixos = { user, pkgs, ... }: { programs.nh = { enable = true; clean.enable = true; clean.extraArgs = "--keep-since 7d --keep 3"; flake = "/home/${user.userName}/nixos-config"; }; }` |
| `programs.steam.enable` | `framework13.nixos` |
| `programs.nix-ld.*` | `den.aspects.nix-ld.nixos` (comment says it exists for Handy; keep the library list verbatim) |
| `system.stateVersion = "25.05"` | `framework13.nixos` |
| `modules/desktop/_niri.nix` import | `den.aspects.niri` (Phase 4D); until then stays as an import |
| `modules/hardware/_printing.nix` import | `den.aspects.printing.nixos` (fold now; it is 30 lines with no arguments) |
| `modules/secrets/_default.nix` import | Phase 5 |

`nh.flake` today is a literal `/home/michaelvessia/nixos-config`. The
`{ user, ... }` form produces the same string. `nh` at host scope with a `user`
argument fans out once per user; framework13 has one user, so one definition.

#### 2.2 claude-casino

| Today | Destination |
|---|---|
| grub loader on `/dev/vda` | `claude-casino.nixos` |
| `networking.hostName` | deleted |
| `services.openssh` key-only block | `den.aspects.ssh-server.nixos` (tts-pi has the same block minus `KbdInteractiveAuthentication`; unify to the stricter one, which is a closure change on tts-pi; note it in the commit) |
| `services.tailscale.enable` | include `den.aspects.tailscale` |
| docker | include `den.aspects.docker` |
| `users.users.cc` | `den.aspects.cc.user = { description = "cc"; extraGroups = [ "wheel" ]; openssh.authorizedKeys.keys = [ ... ]; }` plus define-user and user-shell. Do not include `primary-user` (it would add `networkmanager`). docker group comes from the docker aspect. |
| `nix.settings.accept-flake-config`, `trusted-users = [ "root" "cc" ]` | `claude-casino.nixos = { user, ... }: { nix.settings.trusted-users = [ "root" user.userName ]; nix.settings.accept-flake-config = true; }` |
| `programs.nh` | include `den.aspects.nh` |
| `system.stateVersion` | `claude-casino.nixos` |

#### 2.3 tts-pi

| Today | Destination |
|---|---|
| `boot.supportedFilesystems` mkForce block | `tts-pi.nixos` |
| sd-image and raspberry-pi-3 imports | `tts-pi.nixos.imports` |
| `users.users.pi` | `den.aspects.pi = { includes = [ den.batteries.primary-user ]; user = { extraGroups = [ "audio" ]; openssh.authorizedKeys.keys = [ ... ]; }; }`. `primary-user` gives wheel and networkmanager, same as today. |
| `security.sudo.wheelNeedsPassword = false` | `tts-pi.nixos` |
| `services.openssh` | include `den.aspects.ssh-server` |
| `nix.settings` (`trusted-users`, `require-sigs = false`) | `tts-pi.nixos = { user, ... }: ...` |
| `environment.systemPackages` | `tts-pi.nixos` |
| snapserver, snapclient, tts scripts, `tts-server`, firewall ports | `den.aspects.snapcast-tts.nixos` (one aspect; the Python and shell scripts move verbatim) |
| ALSA block | `tts-pi.nixos` |
| `hardware.enableAllFirmware` | `tts-pi.nixos` |
| `system.stateVersion` | `tts-pi.nixos` |
| `modules/secrets/_tts-pi.nix` | Phase 5 |

`users.pi.classes = [ "user" ]` keeps Home Manager out of the Pi closure.

#### 2.4 flomac

| Today (`hosts/flomac/default.nix`) | Destination |
|---|---|
| `fonts.packages` | `flomac.darwin` |
| `homebrew.*` (taps, brews, casks, masApps, extraConfig) | `den.aspects.homebrew.darwin` (the cask list is long and changes often; its own file `modules/programs/homebrew.nix` keeps host aspect small). Included by flomac. |
| `system.activationScripts.extraActivation.text` (brew trust) | `den.aspects.homebrew.darwin = { user, ... }: ...` using `user.userName`. Taps are listed once in a `let` and used by both the `taps` list and the trust loop. |
| `system.stateVersion = 5` | `flomac.darwin` |
| `system.primaryUser` | deleted (primary-user battery) |
| `system.defaults.*` including symbolic hotkeys | `den.aspects.macos-defaults.darwin` |
| `nix.enable = false` | `flomac.darwin` with the Determinate comment |
| `nixpkgs.config.allowUnfree` | deleted (nix-settings aspect, `os` half) |
| `users.users.${username}` | deleted (define-user sets `name` and `home = /Users/<name>`) |
| `networking.hostName/computerName/localHostName` | `hostName` deleted (battery); `computerName` and `localHostName` in `flomac.darwin` as `{ host, ... }: { networking.computerName = host.hostName; ... }` |
| `environment.systemPackages` | `flomac.darwin` |

Verify `define-user` output for darwin: it sets `users.users."michael.vessia" = { name; home = "/Users/michael.vessia"; }`, which is what the host file sets today.

Gate after each host: identical closure, except the documented ssh-server change on tts-pi. Owner activates on framework13, claude-casino, flomac; rebuilds the Pi image.

### Phase 3: users and bundles

Create the bundle aspects and rewrite the four user aspects to use them. The
bundles still point at `_` leaves until Phase 4 folds them.

```nix
# modules/users/michaelvessia.nix
{ den, inputs, ... }: {
  den.aspects.michaelvessia = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "zsh")
      den.aspects.cli-base
      den.aspects.agents
      den.aspects.desktop-linux
      den.aspects.homelab-clis
      den.aspects.takopi
    ];
    user = {
      description = "Michael Vessia";
      extraGroups = [ "input" ];
    };
    homeManager = { pkgs, ... }: {
      home.packages = [ inputs.grok-bot.packages.${pkgs.system}.default ];
    };
  };
}
```

```nix
# modules/users/michael.vessia.nix
{ den, ... }: {
  den.aspects."michael.vessia" = {
    includes = [
      den.batteries.primary-user
      (den.batteries.user-shell "zsh")
      den.aspects.cli-base
      den.aspects.agents
      den.aspects.mac-desktop
      den.aspects.work
      den.aspects.sops-flomac
    ];
    homeManager = { config, ... }: {
      agentHarnesses.executor.url = "https://executor.flostag-us-west-2.flokubernetes.com/mcp";
      home.file.".homebrew/brew.env".text = "HOMEBREW_NO_REQUIRE_TAP_TRUST=1\n";
      launchd.agents.sops-nix-env = { ...verbatim... };
    };
  };
}
```

```nix
# modules/users/cc.nix
{ den, ... }: {
  den.aspects.cc = {
    includes = [
      (den.batteries.user-shell "zsh")
      den.aspects.cli-base
      den.aspects.agents
      den.aspects.takopi
    ];
    user = {
      description = "cc";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ ... ];
    };
  };
}
```

`cc` today imports `agents`, `nvf`, `common`, `git`, `shell`, `zellij`, `ssh`,
`takopi`. `cli-base` = `common` + `shell` + `git` + `ssh` + `zellij` + `nvf` +
`stack` + `worktrunk` + `herdr` + `user-scripts`. So `cc` gains `stack`,
`worktrunk`, `herdr`, and the `~/bin` scripts (`users/common.nix` was already
imported by cc, so scripts are not new). This is a closure change on
claude-casino: three more packages. Accept it, or define `cli-base` without
those three and add `den.aspects.cli-extras` to the two Michael users. The plan
recommends accepting it; the commit message lists the three packages.

`worktrunk`'s Home Manager module is in `sharedModules` today only for
framework13 and flomac, not claude-casino. Moving it into `den.aspects.worktrunk.homeManager.imports`
makes the module travel with the aspect, so claude-casino gets it correctly.

`den.aspects.homelab-clis` is included by michaelvessia directly. Alternative:
include it from a `{ host, user, ... }` policy when `host.homelab`. The direct
include is simpler and there is one homelab host. The skills aspect reads
`host.homelab` because its module already branches on the flag.

Gate: closures identical except the three cc packages.

### Phase 4: fold leaf modules into aspects

Each group is one branch and one review. Within a group, one commit per file
is fine. A fold is: rename `_x.nix` to `x.nix`, wrap the body in
`den.aspects.<name>.homeManager = { pkgs, ... }: { ... }` (or `nixos`), replace
module-argument uses of `inputs` with the file-level `inputs`, replace
`pkgs-unstable.foo` with `pkgs.unstable.foo`, remove the platform guard if the
aspect is now included only on one platform, and update the bundle include to
`den.aspects.<name>`. When the last `_` leaf of a bundle is gone, remove that
bundle's transitional `imports` list.

The transitional `extraSpecialArgs` in `modules/home-manager.nix` is deleted in
the last group merged. Until then, folded aspects must not rely on it.

Closure change: none expected per fold. Removing `lib.mkIf pkgs.stdenv.isLinux`
from a module included only on Linux does not change its Linux output.

#### 4A: CLI base (7 files)

| File | Aspect | Notes |
|---|---|---|
| `programs/_common.nix` | `cli-base` | `pkgs-unstable.gws` becomes `pkgs.unstable.gws`. `callPackage ./linear-cli` becomes `callPackage ../../pkgs/linear-cli.nix`. The darwin-only list (`pngpaste`, pup, rootly) moves to `work` and `mac-desktop`. The Linux-only list moves to `desktop-linux` (`orca`, `signal-desktop`, clipboards) and to `cli-base` as a flat-form `{ host, pkgs, ... }: lib.optionals (host.class == "nixos") [...]` for the diagnostic tools (`iotop`, `strace`, ...) that cc also needs. |
| `modules/_users-common.nix` | `user-scripts` | `home.file` scripts loop and `home.sessionPath`. Path becomes `../../scripts`. `home.stateVersion` deleted (den.default). |
| `programs/_shell.nix` | `shell` | Unchanged body. |
| `programs/_git.nix` | `git` | `pkgs-unstable.gh` becomes `pkgs.unstable.gh` (two sites). |
| `programs/_ssh.nix` | `ssh` | `services.ssh-agent.enable = lib.mkDefault pkgs.stdenv.isLinux` stays; ssh is included on darwin too. |
| `programs/_zellij.nix` | `zellij` | Unchanged. |
| `programs/_stack.nix`, `_worktrunk.nix`, `_herdr.nix` | `stack`, `worktrunk`, `herdr` | `worktrunk` gains `homeManager.imports = [ inputs.worktrunk.homeModules.default ]`; the `sharedModules` entry is removed from `framework13` and `flomac` `provides.to-users`. Update the comment in `worktrunk.nix` that names `flake.nix`. |

#### 4B: agents (10 files)

| File | Aspect | Notes |
|---|---|---|
| `agents/_default.nix` | `agents` | Declares the option: `homeManager = { lib, ... }: { options.agentHarnesses.executor.url = lib.mkOption {...}; }`. Because this module declares `options`, any config in the same module must sit under `config = {}`. Includes: `agents.skills`, `agents.claude-code`, `agents.codex`, `agents.pi`, `agents.omp`, `agents.opencode`, `agents.collie`, `agents.agentsview`, `agents.plannotator`. |
| `agents/_shared.nix` | `agents.skills` (`den.aspects.agents.provides.skills`) | `enableHomelabSkills` module argument becomes flat-form `{ host, config, lib, ... }:` reading `host.homelab`. `imports = [ inputs.agent-skills-nix.homeManagerModules.default ]` uses the file-level `inputs`. Keep the per-skill symlink layout and its comment (AGENTS.md rule). |
| `agents/claude-code/_default.nix` | `agents.claude-code` | `lib.optionalAttrs pkgs.stdenv.isDarwin` for the floai marketplace stays (one aspect, two platforms). |
| `agents/_codex.nix` | `agents.codex` | Same darwin guard stays. `inputs.llm-agents` from file scope. |
| `agents/pi/_default.nix` | `agents.pi` | `piDir` string unchanged (`modules/programs/agents/pi`). `inputs.garage`, `inputs.llm-agents` from file scope. |
| `agents/omp/_default.nix` | `agents.omp` | `ompDir` unchanged. |
| `agents/_opencode.nix` | `agents.opencode` | `opencodeDir` unchanged. |
| `agents/_collie.nix`, `_agentsview.nix`, `_plannotator.nix` | the matching provides | trivial |

#### 4C: editors and terminals (6 files + nvf 17 files)

| File | Aspect | Notes |
|---|---|---|
| `nvf/_default.nix` | `nvf` | `homeManager.imports = [ inputs.nvf.homeManagerModules.default ]`, `programs.nvf.enable`. The 16 sibling files each become `{ den.aspects.nvf.homeManager.programs.nvf.settings.vim.<area> = ...; }` at the same path. `pkgs-unstable` in `languages.nix` becomes `pkgs.unstable`. Delete the imports list. |
| `programs/_ghostty.nix` | `ghostty` | `home.packages` and the themes symlink are Linux-only today by guard. Split: `ghostty.homeManager` holds the shared config text; `ghostty.provides.nix-package.homeManager` holds the package and themes link. `desktop-linux` includes `den.aspects.ghostty.nix-package`; `mac-desktop` includes `den.aspects.ghostty`. Guards removed. |
| `zed/_default.nix` | `zed` | Same split: symlinks shared, `pkgs.zed-editor` under `zed.provides.nix-package`. Symlink paths unchanged. |
| `programs/_media.nix` | `media` | `spotify`, `yt-dlp` shared; `pinta`, `telegram-desktop` under `media.provides.linux`. |
| `programs/_cmux.nix` | `mac-desktop.provides.cmux` | Guard removed (mac only). |
| `programs/_takopi.nix` | `takopi` | unchanged |

#### 4D: Linux desktop (5 files, closure-sensitive)

| File | Aspect | Notes |
|---|---|---|
| `desktop/_niri.nix` (system) + `programs/_niri.nix` (home) | `niri` | One file `modules/desktop/niri.nix`: `nixos = { imports; nixpkgs.overlays = [ inputs.niri.overlays.niri ]; ...system body... }`, `provides.to-users.homeManager = { imports = [ inputs.niri.homeModules.niri inputs.dms.homeModules.dank-material-shell inputs.dms.homeModules.niri ]; ...home body... }`. The home body is 586 lines; move it verbatim. `pkgs-unstable.quickshell` becomes `pkgs.unstable.quickshell`. `inputs.dms`, `inputs.dgop` from file scope. `osConfig` stays available (Home Manager as a NixOS module provides it). Remove `lib.mkIf pkgs.stdenv.isLinux`. `framework13` includes `den.aspects.niri`; `desktop-linux` does not (the host decides the compositor, the user gets it through `to-users`). |
| `dms/_default.nix` | `dms` | `provides.to-users` on niri, or include from `desktop-linux`; choose `desktop-linux` because it is user tooling (save/restore scripts). Snapshot path unchanged. |
| `browsers/_brave.nix` | `browsers.brave` | Guard removed. `browsers/_default.nix` deleted. |
| `programs/_syncthing.nix` | `syncthing` | Guard removed. |
| `programs/_transcribe.nix`, `_x-to-obsidian.nix` | `transcribe`, `x-to-obsidian` | Guards removed. `x-to-obsidian` module argument becomes `inputs.x-to-obsidian` from file scope. |

The framework13 VM variant references `home-manager.users.michaelvessia.programs.niri.settings.spawn-at-startup`. This keeps working because `to-users` delivers the niri Home Manager module to that user.

Gate for 4D: identical closure and one VM boot.

#### 4E: macOS desktop and work (6 files)

| File | Aspect | Notes |
|---|---|---|
| `programs/_karabiner.nix`, `_hammerspoon.nix`, `_raycast.nix` | `mac-desktop.provides.karabiner`, `.hammerspoon`, `.raycast` | Guards removed. `raycast.nix` is a comment-only module; keep it as the documentation home for Raycast keybinds, or move the comment into `mac-desktop` and delete the file. Recommend delete. |
| `programs/_floai.nix` | `work.provides.floai` | `inputs.floai` from file scope. The `hasFloai` null-check stays (the input is private and can be absent on a fresh clone without SSH access). Guard `isDarwin` removed. |
| pup, rootly packages | `work.homeManager.home.packages` | `pkgs.unstable.callPackage ../../pkgs/pup.nix {}` and `pkgs.callPackage ../../pkgs/rootly.nix {}`. |
| `pngpaste` | `mac-desktop.homeManager.home.packages` | Hammerspoon's `screensend` needs it. |

#### 4F: homelab CLIs (4 files)

`fmcal`, `paperless-cli`, `hass-cli`, `kuma-cli` become `homelab-clis.provides.<name>`. Guards removed. `inputs.fmcal`, `inputs.paperless-cli` from file scope.

#### 4G: services and hardware (already folded in Phase 2)

`printing`, `audio`, `docker`, `tailscale`, `nh`, `nix-ld`, `ssh-server`,
`snapcast-tts`, `homebrew`, `macos-defaults` were created in Phase 2. Nothing
left.

#### 4H: close-out

1. `git ls-files 'modules/**/_*.nix'` returns nothing.
2. Delete `extraSpecialArgs` from `modules/home-manager.nix`.
3. Delete `provides.to-users.homeManager.imports` transitional lists from host aspects.
4. `grep -rn "pkgs-unstable\|enableHomelabSkills\|specialArgs" modules` returns nothing.
5. `grep -rn "isLinux\|isDarwin" modules` returns only: `ssh.nix` (ssh-agent), `shell.nix` (direnv override, `AGENT_BROWSER_EXECUTABLE_PATH`), `agents/claude-code`, `agents/codex`, `agents/pi` (CA wrapper flags). Each of these is one aspect that serves both platforms. Everything else is gone.

Gate: identical closures for all hosts.

### Phase 5: secrets

| Today | Destination |
|---|---|
| `modules/secrets/_default.nix` (NixOS, framework13) | `den.aspects.sops-framework13.nixos = { user, lib, ... }: { imports = [ inputs.sops-nix.nixosModules.sops ]; sops = { defaultSopsFile = ../../secrets/framework13.yaml; age.keyFile = "/home/${user.userName}/.config/sops/age/keys.txt"; secrets = lib.genAttrs secretNames (_: { owner = user.userName; }); }; }` with `secretNames` as one list in a `let`. Included by `framework13`. The fifteen `owner = "michaelvessia"` lines become one. |
| `modules/secrets/_tts-pi.nix` | `den.aspects.sops-tts-pi.nixos` with the sops module import and `age.sshKeyPaths`. Included by `tts-pi`. |
| `modules/secrets/_flomac.nix` (Home Manager) | `den.aspects.sops-flomac.homeManager = { config, lib, ... }: { imports = [ inputs.sops-nix.homeManagerModules.sops ]; ...verbatim... }` with `age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt"`. Included by `"michael.vessia"`. The `sharedModules` sops entry for flomac is deleted. |
| `sops-nix.nixosModules.sops` in `flake.nix` module lists | moved into the two nixos aspects above; claude-casino imports the module today but declares no secrets, so `claude-casino` includes nothing (closure change: the sops module leaves the claude-casino closure; note it). |

Shell exports in `shell.nix` and the wrappers in `x-to-obsidian` keep reading
secret files at runtime. Not changed by this plan.

Docs: `README.md` "Adding a new secret" step 3 becomes "Add the name to the
`secretNames` list in `modules/secrets/<host>.nix`". "Adding a new host" step 4
becomes "Create `modules/secrets/<host>.nix` with a `den.aspects.sops-<host>`
aspect and include it from the host aspect." `AGENTS.md` secrets block: update
the path sentence.

Gate: identical closures except claude-casino (sops module removed). Owner
checks `/run/secrets` after activation on framework13 and
`~/.config/sops-nix/secrets` on flomac.

### Phase 6: flomac flake removal (if D1 accepted; otherwise Appendix C)

Done in Phase 1 for the files. This phase is the owner's verification:

1. On flomac: `sudo darwin-rebuild switch --flake ~/nixos-config#flomac`.
2. `reload` (`nh darwin switch`) works with `NH_FLAKE=$HOME/nixos-config`.
3. `scripts/nixos/upgrade` runs `nix flake update` at the repo root and rebuilds.
4. Delete the stale `bun2nix` input if nothing uses it (nothing in `modules/` references it today).

### Phase 7: documentation and agent guidance

Most edits happen in the phase that changes the thing. This phase is the audit.

| Document | Change |
|---|---|
| `README.md` | Rewrite "Directory Structure" (section 2.1). Add "Adding a feature", "Adding a host", "Adding a user" recipes (Appendix B). Secrets section as in Phase 5. Keep OMP section; its paths are unchanged. |
| `AGENTS.md`, `CLAUDE.md` | Replace with Appendix A. Keep both files identical. |
| `docs/initial-setup.md` | No change (keys and age setup are layout-independent). |
| `hosts/tts-pi/README.md` | No change (`nix build .#images.tts-pi` and the `--target-host` command are unchanged). Confirm after Phase 2. |
| `docs/den-migration-plan.md` | Mark each phase done with its commit hash. When Phase 8 is done, move the plan to `docs/history/` or delete it; the recipes live in README and AGENTS.md. |
| Comments in `.nix` files | `desktop/niri.nix` (no longer two files), `secrets` note about `shell.nix`, `floai.nix` (flomac flake), `worktrunk.nix` (`sharedModules`), `cmux.nix` and `zed` (`hosts/flomac/default.nix` becomes `modules/programs/homebrew.nix`), `common.nix` (pi note), `herdr.nix` and `ghostty.nix` cross references stay valid because file names do not change. |
| `scripts/nixos/upgrade`, `update-flake-input` | Phase 1 edit; re-read for stale comments. |
| Agent skills under `modules/programs/agents/shared/skills/` | None reference repository paths (checked). No change. |
| den agent skill | Copy `den/.agents/skills/den-debugging/SKILL.md` is NOT useful here; it is for developing den itself. Instead add a short `den` section to `AGENTS.md` (Appendix A) with the "where config lands" rules and the debug commands. |

### Phase 8: hardening (optional, after everything above)

1. `modules/nh.nix`: `perSystem.packages = den.lib.nh.denPackages { fromFlake = true; } pkgs;` gives `nix run .#framework13` and `nix run .#flomac` wrappers. Optional; `reload` already works.
2. `flake.checks`: a `perSystem.checks` that evaluates each host's toplevel for its system, so `nix flake check` catches evaluation errors on all hosts. Today `nix flake check --no-build` already evaluates `nixosConfigurations`; keep as is unless a CI workflow is added.
3. Strict mode: `imports = [ inputs.den.flakeModules.strict ];` rejects undeclared host attributes. Only `homelab` is custom and it is declared, so strict mode is safe. Enable it.
4. `den.batteries.unfree`: replace global `allowUnfree = true` with per-aspect names. Not recommended; the closure would change wherever an unfree package is pulled implicitly, and the gain is small.
5. Sops templates for the shell exports in `shell.nix`. Separate project.

---

## 5. Complete file mapping

Every tracked `.nix` file and every file the plan touches.

| Current path | Action | New path or destination |
|---|---|---|
| `flake.nix` | rewrite | `flake.nix` (inputs + one-line outputs) |
| `flake.lock` | update | den, import-tree, flake-parts added; bun2nix decision in Phase 6 |
| `hosts/flomac/flake.nix`, `hosts/flomac/flake.lock` | delete (D1) | |
| `hosts/framework13/default.nix` | fold | `modules/hosts/framework13.nix` + aspects (Phase 2.1) |
| `hosts/framework13/hardware-configuration.nix` | keep | imported by `den.aspects.framework13.nixos` |
| `hosts/framework13/certs/caddy-local-root.crt` | keep | referenced from `modules/hosts/framework13.nix` |
| `hosts/claude-casino/default.nix` | fold | `modules/hosts/claude-casino.nix` |
| `hosts/claude-casino/hardware-configuration.nix` | keep | |
| `hosts/tts-pi/default.nix` | fold | `modules/hosts/tts-pi.nix` + `modules/programs/snapcast-tts.nix` |
| `hosts/tts-pi/README.md` | keep | verify commands after Phase 2 |
| `hosts/flomac/default.nix` | fold | `modules/hosts/flomac.nix` + `modules/programs/homebrew.nix` + `modules/programs/macos-defaults.nix` |
| `users/common.nix` | move then fold | `modules/_users-common.nix` then `modules/programs/user-scripts.nix` |
| `users/michaelvessia/home.nix` | fold | `modules/users/michaelvessia.nix` |
| `users/michael.vessia/home.nix` | fold | `modules/users/michael.vessia.nix` |
| `users/cc/home.nix` | fold | `modules/users/cc.nix` |
| (new) | create | `modules/users/pi.nix` |
| `modules/desktop/default.nix` | delete | |
| `modules/desktop/niri.nix` | rename `_`, fold in 4D with `programs/niri.nix` | `modules/desktop/niri.nix` (`den.aspects.niri`) |
| `modules/hardware/printing.nix` | fold in Phase 2 | `modules/hardware/printing.nix` (`den.aspects.printing`) |
| `modules/secrets/default.nix` | rename `_`, fold in Phase 5 | `modules/secrets/framework13.nix` |
| `modules/secrets/flomac.nix` | rename `_`, fold in Phase 5 | `modules/secrets/flomac.nix` |
| `modules/secrets/tts-pi.nix` | rename `_`, fold in Phase 5 | `modules/secrets/tts-pi.nix` |
| `modules/programs/default.nix` | delete in 4A | |
| `modules/programs/common.nix` | rename `_`, fold 4A | `den.aspects.cli-base` |
| `modules/programs/shell.nix`, `git.nix`, `ssh.nix`, `zellij.nix`, `stack.nix`, `worktrunk.nix`, `herdr.nix` | rename `_`, fold 4A | same names |
| `modules/programs/agents/default.nix` | rename `_`, fold 4B | `den.aspects.agents` |
| `modules/programs/agents/shared.nix` | rename `_`, fold 4B | `den.aspects.agents.skills` |
| `modules/programs/agents/shared/instructions.md`, `shared/skills/**` | keep | unchanged paths |
| `modules/programs/agents/claude-code/default.nix`, `agents/*.md` | rename `_`, fold 4B; md files keep | |
| `modules/programs/agents/codex.nix`, `opencode.nix`, `collie.nix`, `agentsview.nix`, `plannotator.nix` | rename `_`, fold 4B | |
| `modules/programs/agents/pi/default.nix` | rename `_`, fold 4B | `settings.json`, `settings-extensions.json` unchanged |
| `modules/programs/agents/omp/default.nix`, `config.yml` | fold; yml unchanged | |
| `modules/programs/agents/opencode/*.json` | keep | |
| `modules/programs/nvf/*.nix` (17) | rename `_`, fold 4C | each contributes to `den.aspects.nvf` |
| `modules/programs/browsers/default.nix` | delete 4D | |
| `modules/programs/browsers/brave.nix` | fold 4D | `den.aspects.browsers.brave` |
| `modules/programs/dms/default.nix`, `dms/config/**` | fold 4D; config unchanged | |
| `modules/programs/niri.nix` | fold 4D into `modules/desktop/niri.nix` | delete after fold |
| `modules/programs/ghostty.nix`, `zed/default.nix`, `zed/*.json`, `media.nix`, `cmux.nix`, `takopi/default.nix` | fold 4C | json unchanged |
| `modules/programs/syncthing.nix`, `transcribe.nix`, `x-to-obsidian.nix` | fold 4D | |
| `modules/programs/karabiner.nix`, `hammerspoon.nix`, `raycast.nix`, `floai.nix` | fold 4E | raycast deleted |
| `modules/programs/fmcal.nix`, `paperless-cli.nix`, `hass-cli.nix`, `kuma-cli.nix` | fold 4F | |
| `modules/programs/linear-cli/default.nix` | move Phase 1 | `pkgs/linear-cli.nix` |
| `modules/programs/pup/default.nix` | move Phase 1 | `pkgs/pup.nix` |
| `modules/programs/rootly/default.nix` | move Phase 1 | `pkgs/rootly.nix` |
| `modules/programs/claude-code/skills/**` | keep | not referenced by Nix today; unchanged |
| `scripts/nixos/upgrade` | edit Phase 1 | remove host-flake branch |
| `scripts/**` (others) | keep | |
| `README.md`, `AGENTS.md`, `CLAUDE.md` | edit Phases 1, 5, 7 | |
| `lefthook.yaml`, `.sops.yaml`, `.envrc`, `.gitignore` | keep; `.gitignore` gains `.baseline/` | |
| `.grove/*`, `.sidecar/*` | keep | |

## 6. Special arguments and conditionals, mapped

| Today | Used in | den replacement |
|---|---|---|
| `specialArgs.username` | `hosts/flomac/default.nix`, `flake.nix` | `user.userName` in flat-form darwin module; `define-user`, `primary-user` |
| `specialArgs.inputs` and `extraSpecialArgs = inputs // ...` | 20+ leaf modules (`inputs.llm-agents`, `inputs.nvf`, `inputs.ghostty`, `inputs.dms`, `inputs.dgop`, `inputs.garage`, `inputs.collie`, `inputs.fmcal`, `inputs.paperless-cli`, `inputs.floai`, `inputs.agent-skills-nix`, `inputs.googleworkspace-cli`, `inputs.grok-bot`, `inputs.worktrunk`, `inputs.x-to-obsidian` as `x-to-obsidian`) | file-level `inputs` closed over in each aspect file; transitional `extraSpecialArgs` until Phase 4H |
| `specialArgs.pkgs-unstable` | `common.nix` (gws, pup, signal-desktop), `git.nix` (gh), `niri.nix` (quickshell), `nvf/languages.nix`, `nvf/default.nix` (unused arg) | `pkgs.unstable.<name>` via overlay |
| `specialArgs.enableHomelabSkills` | `agents/shared.nix` | `host.homelab` via flat-form `{ host, ... }` |
| `osConfig` | `niri.nix` (hostname, unused after `hostname` let) | unchanged; provided by Home Manager NixOS module. The `hostname` binding in `niri.nix` is dead code; delete during fold. |
| `lib.mkIf pkgs.stdenv.isLinux` whole-module | `syncthing`, `niri`, `dms`, `x-to-obsidian`, `kuma-cli` | removed; included only via `desktop-linux` / `homelab-clis` / framework13 |
| `lib.optionals pkgs.stdenv.isLinux [...]` | `common.nix`, `media.nix`, `ghostty.nix`, `zed`, `transcribe`, `fmcal`, `paperless-cli`, `hass-cli` | moved into Linux-only provides or aspects |
| `lib.mkIf pkgs.stdenv.isDarwin` whole-module | `raycast`, `karabiner`, `hammerspoon`, `cmux` | removed; `mac-desktop` provides |
| `lib.optionalAttrs pkgs.stdenv.isDarwin` | `claude-code` (floai plugin), `codex` (floai marketplace), `shell.nix` (agent-browser path), `common.nix` (pngpaste, pup, rootly) | claude-code and codex keep the guard (one aspect, both platforms). shell keeps the guard. common's list moves to `work` and `mac-desktop`. |
| `pkgs.stdenv.hostPlatform.isDarwin` direnv override | `shell.nix` | keep |
| `pkgs.stdenv.isLinux` CA wrapper flags | `agents/pi` | keep |
| `services.ssh-agent.enable = mkDefault isLinux` | `ssh.nix` | keep |
| `hasFloai` null check | `floai.nix` | keep (private input may be absent) |
| `home-manager.sharedModules` | `flake.nix` (niri, dms ×2, worktrunk), flomac (sops HM, worktrunk) | `homeManager.imports` inside `niri`, `worktrunk`, `sops-flomac` aspects |
| `nixos-hardware`, `sops-nix` NixOS modules, sd-image | `flake.nix` module lists | `nixos.imports` in host aspects and `sops-*` aspects |

## 7. Risks and how the plan handles them

| Risk | Handling |
|---|---|
| `homeManager` written on a host aspect lands nowhere, silently | Rule 3 in section 2.5. Grep gate in Phase 4H: `grep -n "^\s*homeManager" modules/hosts/*.nix` must be empty. Closure comparison catches the missing content. |
| `nixos` on a user aspect leaks to the host untargeted (den #694) | Rule 4. User aspects use only `user`, `homeManager`, `includes`, and `provides.*`. |
| Flat-form module without `...` fails at evaluation | Rule 6. `nix flake check` catches it. |
| Parametric aspect included where its argument is not in scope is silently inert | Every `{ user, ... }` aspect in this plan is included from a host aspect (user is a descendant) or a user aspect (user in context). Closure comparison catches silent drops. |
| den `latest` tag moves and changes semantics | D2 pins to a tag in the lockfile. Read release notes before `nix flake update den`. Add this to AGENTS.md. |
| `nix.settings` on flomac with `nix.enable = false` | Section 1.3 splits the aspect. |
| Out-of-store symlink targets move | D4: they do not move. Grep gate: the four `nixos-config/modules/programs/...` strings still resolve to tracked files. |
| `dms-config-save` writes to `modules/programs/dms/config` | Unchanged path. |
| The flomac host flake is the documented deployment entry point | D1 removes it; README and `upgrade` change in the same commit; owner verifies on flomac in Phase 6. |
| Private `floai` input blocks evaluation on machines without SSH access | Unchanged from today (root flake already has it). `hasFloai` check stays. |
| `primary-user` adds `networkmanager` to hosts that did not have it | Only `cc` lacks it today; `cc` does not include `primary-user`. |
| `define-user` on darwin sets `users.users.<n>.name` | Same value the host file sets today. |
| Evaluation time grows | den adds a resolution pass per host. Measure `time nix eval` before and after Phase 1; report in the commit. Expect under 20 percent. |
| Rollback | Every phase is one or a few commits on `den-migration`. `master` stays deployable until the branch merges. On a host, `nh os rollback` returns to the previous generation. |

## 8. Acceptance checklist

- [ ] D1 to D6 confirmed by the owner.
- [ ] Baseline captured on `master` with the same `flake.lock`.
- [ ] Phase 1: flake outputs come from den; closures identical; framework13 and flomac activated.
- [ ] Phase 2: four host aspects split; closures identical except tts-pi ssh-server; Pi image builds.
- [ ] Phase 3: four user aspects with bundles; closures identical except cc packages.
- [ ] Phase 4A to 4F merged; `git ls-files 'modules/**/_*.nix'` empty; `extraSpecialArgs` gone; framework13 VM boots with niri and DMS.
- [ ] Phase 5: secrets present at `/run/secrets` on framework13 and `~/.config/sops-nix/secrets` on flomac after activation.
- [ ] Phase 6: flomac deploys from the root flake; `upgrade` works on flomac.
- [ ] Phase 7: README, AGENTS.md, CLAUDE.md updated; every `.nix` comment path re-checked; `grep -rn "hosts/flomac/flake\|users/\|specialArgs\|enableHomelabSkills\|pkgs-unstable" README.md AGENTS.md CLAUDE.md modules scripts` empty.
- [ ] Phase 8: strict mode on; optional nh packages.
- [ ] `.baseline/` refreshed and this plan archived.

---

## Appendix A: AGENTS.md after migration

Replace the whole file with this text (and keep `CLAUDE.md` identical).

```markdown
# nixos-config

Personal declarative configuration for NixOS, nix-darwin, Home Manager, and
sops-nix, wired with den (aspect-oriented Nix). The flake configures
`framework13`, `claude-casino`, `tts-pi`, and `flomac`. Features are aspects
shared across hosts and users.

## Repository map

- `flake.nix` / `flake.lock`: inputs and a one-line `outputs` that loads every
  `.nix` file under `modules/` with import-tree into flake-parts. den turns
  `den.hosts` into `nixosConfigurations` and `darwinConfigurations`.
- `modules/den.nix`: den import, `den.default`, `den.schema` (the `homelab`
  host option, default user classes).
- `modules/hosts/<host>.nix`: the host entity (`den.hosts`) and its host
  aspect (`den.aspects.<host>`): boot, hardware imports, stateVersion, and the
  list of feature aspects the machine includes.
- `modules/users/<user>.nix`: the user aspect: groups, SSH keys, shell battery,
  and the feature bundles the user includes.
- `modules/programs/`, `modules/desktop/`, `modules/hardware/`,
  `modules/secrets/`: feature aspects, one concern per file. Data files
  (JSON, YAML, KDL, Markdown, skills) live beside the aspect that uses them.
- `pkgs/`: `callPackage` expressions. Not loaded by import-tree.
- `hosts/<host>/`: generated hardware configuration and static artifacts.
  Not loaded by import-tree.
- `scripts/`: commands installed into `~/bin` by `den.aspects.user-scripts`;
  keep basenames unique.
- `secrets/`: encrypted YAML. Declarations are in `modules/secrets/`.

## den rules

- An aspect is `den.aspects.<name>` with class keys `nixos`, `darwin`, `os`
  (both), `homeManager`, and `user` (forwarded to `users.users.<name>`), plus
  `includes` and `provides`.
- A host aspect never writes `homeManager`; that content lands nowhere and den
  does not warn. Use `provides.to-users.homeManager` on the host or feature
  aspect, or include the feature from the user aspect.
- A user aspect never writes `nixos` or `darwin`. Use `user` for the account,
  `provides.to-hosts` or `provides.<host>` for host config.
- Use flake inputs by closing over the file-level `inputs` argument. Class
  modules do not receive `inputs`, `pkgs-unstable`, or `username`.
- `pkgs.unstable` is the nixpkgs-unstable package set (overlay in
  `modules/nixpkgs.nix`).
- A class module that takes `host` or `user` next to `pkgs`/`config` must end
  with `...`.
- Name every aspect. Do not put anonymous functions in `includes`.
- Platform guards (`isLinux`, `isDarwin`) are allowed only inside an aspect
  that both platforms include. Otherwise include the aspect only where it
  applies.
- Files whose name starts with `_` are not loaded. Do not create new ones.

## Recipes

- New feature: create `modules/programs/<name>.nix` defining
  `den.aspects.<name>`, then add `den.aspects.<name>` to the `includes` of a
  host, a user, or a bundle (`cli-base`, `desktop-linux`, `mac-desktop`,
  `homelab-clis`, `work`).
- New host: create `modules/hosts/<host>.nix` with `den.hosts.<system>.<host>`
  and `den.aspects.<host>`; put the generated hardware file under
  `hosts/<host>/`; add `modules/secrets/<host>.nix` if it has secrets.
- New user: create `modules/users/<user>.nix` with `den.aspects.<user>` and
  add `users.<user> = { }` to the host entity.

## Working rules

- Put configuration at the narrowest scope: machine-specific in the host
  aspect, person-specific in the user aspect, reusable in a feature aspect.
- Preserve `system.stateVersion` and `home.stateVersion` unless an explicit
  migration requires changing them.
- Add new flake-referenced files to Git before evaluating; Git flakes ignore
  untracked files.
- Do not hand-edit generated hardware configuration; follow each file's
  regeneration notes.
- Never activate a configuration (`reload`, `nh ... switch`, or
  `*-rebuild switch`) unless the user explicitly asks. Validate by formatting,
  checking, evaluating, or building first.

<important if="changing Nix files">
- Run `nix develop --command alejandra --check $(git ls-files '*.nix')`.
- Run `nix flake check --no-build`.
- Evaluate the affected host:
  `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
  (or `darwinConfigurations.flomac`). Build it when the change touches
  packages. Private SSH inputs require the user's existing GitHub
  authentication.
- Changes to a flake input must include its matching lockfile update. den is
  pinned to its `latest` tag; read its release notes before updating it.
</important>

<important if="debugging den">
- `nix repl` then `:lf .` and inspect `nixosConfigurations.<host>.config...`.
- To see den's registry, add `flake.den = den;` to a module temporarily and
  inspect `den.aspects.<name>` and `den.hosts.<system>.<host>` in the REPL.
- If content is missing, check which scope walks the aspect (host vs user)
  and whether the class key can land there. See
  https://den.denful.dev/explanation/where-config-lands/.
</important>

<important if="changing secrets">
- Never commit plaintext credentials anywhere. Edit encrypted YAML with `sops`,
  add the name to the `secretNames` list in `modules/secrets/<host>.nix`, and
  run `./scripts/check-sops-encryption.sh` on changed secret files.
- Do not print decrypted values or include them in diffs, logs, or responses.
</important>

<important if="changing AI-agent tooling">
- Shared agent instructions and skills live under
  `modules/programs/agents/shared/`; each tool's aspect lives beside it under
  `modules/programs/agents/`.
- Pi's tracked `settings.json` and `settings-extensions.json` are intentionally
  writable through out-of-store symlinks that point at
  `~/nixos-config/modules/programs/agents/pi`. The same applies to OMP,
  OpenCode, and Zed. Do not move those directories. Validate changed JSON with
  `jq empty`.
- Preserve the per-skill symlink layout in
  `modules/programs/agents/shared.nix`; it intentionally leaves externally
  installed sibling skills untouched.
</important>
```

## Appendix B: README recipes (add after "Directory Structure")

```markdown
## How the flake is built

`flake.nix` lists inputs and hands every `.nix` file under `modules/` to
flake-parts through import-tree. den (github:denful/den) reads `den.hosts`
and produces `nixosConfigurations` and `darwinConfigurations`. A feature is an
aspect (`den.aspects.<name>`) that holds its NixOS, nix-darwin, and Home
Manager halves together. Hosts and users include aspects.

## Adding a feature

1. Create `modules/programs/<name>.nix`:
   ```nix
   { inputs, ... }: {
     den.aspects.<name> = {
       nixos = { pkgs, ... }: { ... };
       provides.to-users.homeManager = { pkgs, ... }: { ... };
     };
   }
   ```
2. Add `den.aspects.<name>` to `includes` in `modules/hosts/<host>.nix` (system
   feature) or `modules/users/<user>.nix` (user feature), or to a bundle in
   `modules/programs/bundles.nix`.
3. `nix flake check --no-build`, then `nh os build`.

## Adding a host

1. `modules/hosts/<host>.nix` with `den.hosts.<system>.<host>.users.<user> = { };`
   and `den.aspects.<host>` (boot loader, hardware import, `system.stateVersion`).
2. `hosts/<host>/hardware-configuration.nix` from `nixos-generate-config`.
3. Secrets: see below.

## Adding a user

1. `modules/users/<user>.nix` with `den.aspects.<user>` (`includes` bundles,
   `user.extraGroups`, SSH keys).
2. Add `users.<user> = { };` to the host entity. Users get Home Manager by
   default; set `classes = [ "user" ]` to opt out.
```

## Appendix C: keeping a separate flomac flake

If D1 is rejected, `hosts/flomac/flake.nix` becomes:

```nix
{
  inputs = { ...same list as root, kept aligned... };
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ../../modules);
}
```

It evaluates the same modules, so all four hosts appear in both flakes. The
flomac flake exists only to carry a different lockfile. The AGENTS.md rule
"keep shared inputs and module arguments aligned" stays. The `upgrade` script
keeps its host-flake branch.

## References

den docs read for this plan (den `main`, 2026-09-24):

- Core principles, aspects, entities, policies:
  https://den.denful.dev/explanation/core-principles/
- Where config lands (scope rules and the delivery table):
  https://den.denful.dev/explanation/where-config-lands/
- Class modules, flat form, and flake inputs:
  https://den.denful.dev/explanation/class-modules/
- Parametric aspects and the binding rule:
  https://den.denful.dev/explanation/parametric/
- Batteries reference: https://den.denful.dev/reference/batteries/
- Schema reference (host options, `instantiate`, `home-manager.module`):
  https://den.denful.dev/reference/schema/
- Home environments: https://den.denful.dev/guides/home-manager/
- nixpkgs overlays and channels: https://den.denful.dev/guides/nixpkgs/
- Flake outputs from aspects: https://den.denful.dev/guides/flake-outputs/
- Mutual providers (`provides.to-users`, `to-hosts`):
  https://den.denful.dev/guides/mutual/
- Migration guides: https://den.denful.dev/guides/from-flake-to-den/ and
  https://den.denful.dev/guides/migrate/
- Releases and pinning: https://den.denful.dev/releases/
- Debugging: https://den.denful.dev/guides/debug/
- import-tree `_` ignore rule: https://github.com/denful/import-tree
- den issue #694 (user-aspect `nixos` leaks to host):
  https://github.com/denful/den/issues/694
