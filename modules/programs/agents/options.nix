{lib, ...}: {
  options.agentHarnesses.codex.t3Servers = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = {};
    description = "Remote T3 MCP endpoints used by Codex, keyed by server name.";
  };

  options.agentHarnesses.executor.url = lib.mkOption {
    type = lib.types.str;
    default = "https://executor.lan/mcp";
    description = "Executor MCP endpoint shared by configured agent harnesses.";
  };

  options.agentHarnesses.figma.url = lib.mkOption {
    type = lib.types.str;
    default = "https://mcp.figma.com/mcp";
    description = "Figma MCP endpoint shared by configured agent harnesses.";
  };
}
