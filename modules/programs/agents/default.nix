{lib, ...}: {
  options.agentHarnesses.executor.url = lib.mkOption {
    type = lib.types.str;
    default = "https://executor.lan/mcp";
    description = "Executor MCP endpoint shared by configured agent harnesses.";
  };

  imports = [
    ./shared.nix
    ./agentsview.nix
    ./codex.nix
    ./opencode.nix
    ./pi
    ./plannotator.nix
    ./skill-cleanup.nix
    ./claude-code
  ];
}
