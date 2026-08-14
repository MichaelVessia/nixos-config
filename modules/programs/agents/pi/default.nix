{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  piPkg = inputs.llm-agents.packages.${pkgs.system}.pi;

  npmGlobalDir = "${config.home.homeDirectory}/.npm-global";

  # Pi normally manages packages with npm. Garage is a Bun workspace and uses
  # workspace: dependency specifiers that npm cannot install, so dispatch only
  # that Git package to Bun while preserving npm for every other Pi package.
  piPackageManager = pkgs.writeShellApplication {
    name = "pi-package-manager";
    runtimeInputs = [pkgs.bun pkgs.jq pkgs.nodejs];
    text = ''
      if [ -f package.json ] && jq -e '.name == "garage-monorepo"' package.json >/dev/null; then
        exec bun "$@"
      fi

      exec npm "$@"
    '';
  };

  # Wrap pi so that:
  #   - `npm install -g` writes to a user-writable dir instead of the read-only Nix store
  #   - pi skips its self-update check (broken under Nix anyway, see earendil-works/pi#3942)
  #   - telemetry is off
  #   - installed extension bins are on PATH
  piWrapped = pkgs.symlinkJoin {
    name = "pi-wrapped-${piPkg.version or "0"}";
    paths = [piPkg];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set NPM_CONFIG_PREFIX "${npmGlobalDir}" \
        --set PI_SKIP_VERSION_CHECK 1 \
        --set PI_TELEMETRY 0 \
        --prefix PATH : "${npmGlobalDir}/bin"
    '';
  };

  piDir = "${config.home.homeDirectory}/nixos-config/modules/programs/agents/pi";

  claudeBridgeConfig = (pkgs.formats.json {}).generate "claude-bridge.json" {
    askClaude = {
      enabled = true;
      defaultMode = "read";
      defaultIsolated = false;
      allowFullMode = true;
      appendSkills = true;
    };
    provider = {
      plan = "max";
      longContextExtraUsage = false;
      strictMcpConfig = true;
      autoMemoryEnabled = false;
      pathToClaudeCodeExecutable = "${config.home.profileDirectory}/bin/claude";
    };
  };
in {
  home.packages = [piWrapped piPackageManager];

  # Out-of-store symlinks so pi can edit its own settings (install packages,
  # switch models/themes) with the drift landing in the git working tree for
  # review, instead of being clobbered on the next switch. This relies on pi
  # writing settings in place; if pi ever switches to atomic write-and-rename,
  # the first save replaces the symlink with a regular file and edits stop
  # reaching the repo.
  #
  # Notes on non-obvious values in settings.json (JSON can't hold comments):
  #   - npmCommand ["pi-package-manager"]: uses plain npm installs (with
  #     devDeps) for normal packages, but dispatches Garage to Bun because its
  #     workspace: dependency specifiers are not supported by npm. Plain npm is
  #     required for packages like pi-diff-review whose `prepare` script
  #     depends on devDeps (husky).
  #   - pi-autoresearch fork pin: pins Ctrl+Alt+X for the dashboard toggle to
  #     avoid pi's built-in Ctrl+X shortcut.
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${piDir}/settings.json";

  home.file.".pi/agent/settings-extensions.json".source =
    config.lib.file.mkOutOfStoreSymlink "${piDir}/settings-extensions.json";

  # Claude Bridge writes runtime state (for example startupNoticeShown) into
  # this file, so it cannot remain a Home Manager symlink into the Nix store.
  # Re-assert the declarative config as a writable file on each activation.
  home.activation.claudeBridgeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    install -Dm644 ${claudeBridgeConfig} "$HOME/.pi/agent/claude-bridge.json"
  '';

  # herdr's `integration install pi` drops herdr-agent-state.ts here but
  # refuses to create the dir itself; ensure it exists so the install works.
  home.activation.piExtensionsDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    install -d "$HOME/.pi/agent/extensions"
  '';
}
