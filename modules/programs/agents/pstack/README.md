# t3-pstack

Nix pins [t3-pstack](https://github.com/chhoumann/t3-pstack) in `flake.nix`
and `flake.lock`.
`pstack.nix` installs the upstream CLI and a fixed source tree. Home Manager
runs the installer after writing Claude and Codex settings. It discovers
provider homes from local T3 settings and verifies each plugin installation.
A failed installation fails activation instead of reporting success.

The source has a stable link at `~/.local/share/t3-pstack/source`. Marketplace
settings use this link, so upgrades do not keep an old store path. Updates use
Nix, not npm or automatic Git fetches. Run `t3-pstack install` after adding a
new provider home, and `t3-pstack doctor` to check the installed state.

The installer updates Claude Code and Codex homes and Antigravity profiles
that T3 lists on each machine. Antigravity needs CLI version 1.5.0 or later
to load the plugin.

## Local policy

- `shared/pstack-models.md` is the default (work) sheet and splits roles across
  Claude and GPT. Opus takes feature, refactoring, and bug-fix code, judgment,
  and prose. Fable takes performance work and hillclimb. GPT Sol takes swarm
  work. Panels mix Opus and Sol. The session hook is on.
- `shared/pstack-models-personal.md` is used by personal hosts (`framework13`
  and `forge`) via `agentHarnesses.pstack.modelsFile`. It splits roles across
  personal Antigravity (`gemini-4-neon`) and Grok (`grok-4.7`) with no Claude
  or Codex targets.
- Feature and refactoring code and swarm workers run at `medium`. Other
  roles run at `high`.
- `shared/instructions.md` keeps Executor discovery, GitHub-only PR work,
  full-scope completion, and native T3 PR watches.

Do not run setup-pstack to replace the Nix-managed model sheet. Edit the source
sheet and activate the configuration.

- `stable-source.patch` keeps the stable source link in additional Codex homes.
  The Codex CLI otherwise saves the resolved store path, which prevents the
  next Nix pin from reaching those homes.
- `antigravity-store.patch` gives the owner write permission on copied plugin
  directories so the next update can remove the old copy.

## Update and check

Set the release commit in `flake.nix` and run `nix flake update t3-pstack`.
Apply both patches to a copy of the upstream source. Remove write permission
from that copy to match the Nix store. The install check uses temporary homes
and needs the Claude Code and Codex commands on PATH.

```sh
node modules/programs/agents/pstack/check-policy.mjs /path/to/patched/source
node modules/programs/agents/pstack/check-install.mjs /path/to/patched/source
nix develop --command alejandra --check $(git ls-files '*.nix')
```

After the user requests activation, run the host's rebuild command. Then run
`t3-pstack doctor`. Start a new T3 turn to load the plugin and changed rules.
