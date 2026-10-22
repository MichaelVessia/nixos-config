{lib, ...}: {
  options.agentHarnesses.executor.url = lib.mkOption {
    type = lib.types.str;
    default = "https://executor-mcp.bison-gray.ts.net/mcp";
    description = "Personal Executor MCP endpoint shared by configured agent harnesses.";
  };

  options.agentHarnesses.executorFlosports.url = lib.mkOption {
    type = lib.types.str;
    default = "https://executor.flostag-us-west-2.flokubernetes.com/mcp";
    description = "FloSports Executor MCP endpoint shared by configured agent harnesses.";
  };

  options.agentHarnesses.figma.url = lib.mkOption {
    type = lib.types.str;
    default = "https://mcp.figma.com/mcp";
    description = "Figma MCP endpoint shared by configured agent harnesses.";
  };
}
