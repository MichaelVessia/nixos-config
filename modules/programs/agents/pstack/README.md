# t3-pstack

Nix pins [t3-pstack](https://github.com/chhoumann/t3-pstack) in both flakes.
`pstack.nix` installs the upstream CLI and a fixed source tree. Home Manager
runs the installer after writing Claude and Codex settings. It discovers
provider homes from local T3 settings and verifies each plugin installation.
A failed installation fails activation instead of reporting success.

The source has a stable link at `~/.local/share/t3-pstack/source`. Marketplace
settings use this link, so upgrades do not keep an old store path. Updates use
Nix, not npm or automatic Git fetches. Run `t3-pstack install` after adding a
new provider home, and `t3-pstack doctor` to check the installed state.

The plugin supports Claude and Codex in T3. Cursor and OpenCode keep shared
instructions and personal skills. The old vendored vessia skills are removed
by Home Manager. External skill folders remain untouched.

## Local policy

- `shared/pstack-models.md` sets every role to inherit the session model and
  effort. The session hook is off. Invoke `/t3-pstack:poteto-mode` when needed.
- `shared/instructions.md` keeps Executor discovery, GitHub-only PR work,
  full-scope completion, and native T3 PR watches.
- `inherit-panels.patch` lets upstream's model check accept panels made only
  of inheritance aliases. Other model validation stays in place. Shared
  instructions override upstream's mixed-family advice.

Do not run setup-pstack to replace the Nix-managed model sheet. Edit the source
sheet and activate the configuration.

- `stable-source.patch` keeps the stable source link in additional Codex homes.
  The Codex CLI otherwise saves the resolved store path, which prevents the
  next Nix pin from reaching those homes.

## Update and check

Update the same commit in both flakes and their locks. Apply the patch to a
copy of that upstream source, then run the checks. The install check needs
Claude and Codex on PATH and uses temporary configuration homes:

```sh
node modules/programs/agents/pstack/check-policy.mjs /path/to/patched/source
node modules/programs/agents/pstack/check-install.mjs /path/to/patched/source
nix develop --command alejandra --check $(git ls-files '*.nix')
```

After the user requests activation, run the host's rebuild command. Then run
`t3-pstack doctor`. Start a new T3 turn to load the plugin and changed rules.
