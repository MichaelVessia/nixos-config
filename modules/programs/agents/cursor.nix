{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  sharedInstructions = builtins.readFile ./shared/instructions.md;

  # Cursor applies ~/.cursor/rules/*.mdc.
  rule = name: description: body:
    pkgs.writeText name (
      ''
        ---
        description: ${description}
        alwaysApply: true
        ---
      ''
      + body
    );

  # Same servers as Claude Code and Codex. Cursor infers HTTP from `url`.
  # It has no per-tool deny, so executor's resume tool stays available.
  # Activation installs a regular file. A store symlink is read-only, and
  # Cursor rewrites this path when MCP servers change.
  mcpConfig = (pkgs.formats.json {}).generate "cursor-mcp.json" {
    mcpServers = {
      figma.url = config.agentHarnesses.figma.url;
      executor-flosports.url = config.agentHarnesses.executorFlosports.url;
      executor.url = config.agentHarnesses.executor.url;
    };
  };
in {
  # T3's local Cursor SDK reuses MCP credentials but cannot start OAuth login.
  home.packages = [inputs.llm-agents.packages.${pkgs.system}.cursor-agent];

  home.file.".cursor/rules/instructions.mdc".source = rule "cursor-instructions.mdc" "Shared agent instructions" sharedInstructions;

  home.activation.cursorMcpConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD install -Dm644 ${mcpConfig} "$HOME/.cursor/mcp.json"
  '';
}
