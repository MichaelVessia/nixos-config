{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  piPkg = inputs.llm-agents.packages.${pkgs.system}.pi;

  npmGlobalDir = "${config.home.homeDirectory}/.npm-global";

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

  piThemesFiltered = {
    source = "npm:pi-themes";
    themes = [
      "themes/*.json"
      "!themes/gruvbox-dark.json"
    ];
  };

  curatedThemesFiltered = {
    source = "npm:@victor-software-house/pi-curated-themes";
    themes = [
      "themes/*.json"
      "!themes/catppuccin-mocha.json"
    ];
  };

  packages = [
    {source = "npm:pi-subagents";}
    {source = "npm:pi-mcp-adapter";}
    {source = "npm:pi-web-access";}
    {source = "npm:pi-add-dir";}
    {source = "npm:@plannotator/pi-extension";}
    {source = "npm:@juanibiapina/pi-extension-settings";}
    {source = "npm:@juanibiapina/pi-powerbar";}
    {source = "npm:@tmustier/pi-usage-extension";}
    {source = "npm:@tmustier/pi-raw-paste";}
    {source = "git:github.com/tintinweb/pi-manage-todo-list@b75c449aa85ce328e9a8b632f62bf642aed40359";}
    {source = "npm:pi-btw";}
    {source = "npm:pi-interactive-shell";}
    {source = "npm:pi-dynamic-workflows";}
    # Fork pins Ctrl+Alt+X for the dashboard toggle to avoid pi's built-in Ctrl+X shortcut.
    {source = "git:github.com/MichaelVessia/pi-autoresearch@76aa69464cd8d8028538ec8102ae91ea75df5736";}
    {source = "npm:@tmustier/pi-ralph-wiggum";}
    {source = "npm:@every-env/compound-plugin";}
    piThemesFiltered
    {source = "npm:pi-cyber-ui";}
    curatedThemesFiltered
    {source = "npm:pi-terminal-theme";}
  ];

  subagentBuiltins = [
    "context-builder"
    "planner"
    "researcher"
    "reviewer"
    "scout"
    "worker"
  ];

  piSettings = {
    inherit packages;
    defaultProvider = "openai-codex";
    defaultModel = "gpt-5.5";
    defaultThinkingLevel = "xhigh";
    enabledModels = [
      "openai-codex/gpt-5.5"
      "openai-codex/gpt-5.3-codex-spark"
    ];
    theme = "catppuccin-mocha";
    # Forces pi to use plain `npm install` (with devDeps) for git sources
    # instead of `npm install --omit=dev`. Required for packages like
    # pi-diff-review whose `prepare` script depends on devDeps (husky).
    npmCommand = ["npm"];
    subagents = {
      agentOverrides = lib.genAttrs subagentBuiltins (_: {model = "";});
    };
  };

  piExtensionSettings = {
    powerbar = {
      # Keep Cyber UI's detailed model/context footer; use powerbar for git,
      # cumulative session tokens/cost, and the provider only.
      left = "git-branch,tokens";
      right = "provider";
      separator = " │ ";
      placement = "belowEditor";
      "bar-style" = "blocks";
      "bar-width" = "10";
    };
  };

  piSettingsFile = pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings);
  piExtensionSettingsFile = pkgs.writeText "pi-settings-extensions.json" (builtins.toJSON piExtensionSettings);
in {
  config = {
    home.packages = [piWrapped];

    home.activation.piConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      install -Dm644 ${piSettingsFile} "$HOME/.pi/agent/settings.json"
      install -Dm644 ${piExtensionSettingsFile} "$HOME/.pi/agent/settings-extensions.json"
      # herdr's `integration install pi` drops herdr-agent-state.ts here but
      # refuses to create the dir itself; ensure it exists so the install works.
      install -d "$HOME/.pi/agent/extensions"
    '';
  };
}
