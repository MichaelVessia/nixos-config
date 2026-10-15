{lib, ...}: {
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
