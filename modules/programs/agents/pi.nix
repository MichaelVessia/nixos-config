{
  lib,
  pkgs,
  ...
}: let
  piThemesFiltered = {
    source = "npm:pi-themes";
    themes = [
      "themes/*.json"
      "!themes/catppuccin-mocha.json"
      "!themes/gruvbox-dark.json"
    ];
  };

  packages = [
    {source = "npm:pi-subagents";}
    {source = "npm:pi-mcp-adapter";}
    {source = "npm:pi-web-access";}
    {source = "npm:pi-memory-md";}
    {source = "git:github.com/badlogic/pi-diff-review@1584211692c49780ecd0f490a82762b0823fd475";}
    {source = "npm:@devkade/pi-plan";}
    {source = "npm:pi-simplify";}
    {source = "npm:pi-add-dir";}
    {source = "npm:pi-prompt-template-model";}
    {source = "npm:@plannotator/pi-extension";}
    {source = "npm:@juanibiapina/pi-powerbar";}
    {source = "npm:@juanibiapina/pi-extension-settings";}
    {source = "npm:@tmustier/pi-usage-extension";}
    {source = "npm:@tmustier/pi-raw-paste";}
    {source = "git:github.com/tintinweb/pi-manage-todo-list@b75c449aa85ce328e9a8b632f62bf642aed40359";}
    {source = "npm:pi-btw";}
    {source = "npm:pi-interactive-shell";}
    # Fork pins Ctrl+Alt+X for the dashboard toggle to avoid pi's built-in Ctrl+X shortcut.
    {source = "git:github.com/MichaelVessia/pi-autoresearch@76aa69464cd8d8028538ec8102ae91ea75df5736";}
    {source = "npm:@tmustier/pi-ralph-wiggum";}
    {source = "npm:@every-env/compound-plugin";}
    piThemesFiltered
    {source = "git:github.com/javierportillo/pi-hackerman@63b0a3ef2c7b14985ffeb6cac44614ba59cd5693";}
    {source = "npm:pi-cyber-ui";}
    {source = "npm:@victor-software-house/pi-curated-themes";}
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
    defaultThinkingLevel = "high";
    subagents = {
      agentOverrides = lib.genAttrs subagentBuiltins (_: {model = "";});
    };
  };

  piSettingsFile = pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings);
in {
  config = {
    home.activation.piConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      install -Dm644 ${piSettingsFile} "$HOME/.pi/agent/settings.json"
    '';
  };
}
