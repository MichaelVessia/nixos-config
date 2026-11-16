{
  config,
  lib,
  ...
}: {
  # Only personal hosts reach the homelab Executor.
  options.agentHarnesses.executor.enable = lib.mkEnableOption "the personal Executor MCP server";

  options.agentHarnesses.executor.url = lib.mkOption {
    type = lib.types.str;
    default = "https://executor-mcp.bison-gray.ts.net/mcp";
    description = "Personal Executor MCP endpoint shared by configured agent harnesses.";
  };

  options.agentHarnesses.executorFlosports.url = lib.mkOption {
    type = lib.types.str;
    default = "https://executor.flosports.tv/mcp";
    description = "FloSports Executor MCP endpoint shared by configured agent harnesses.";
  };

  options.agentHarnesses.figma.url = lib.mkOption {
    type = lib.types.str;
    default = "https://mcp.figma.com/mcp";
    description = "Figma MCP endpoint shared by configured agent harnesses.";
  };

  options.agentHarnesses.cliproxyHub.url = lib.mkOption {
    type = lib.types.str;
    default = "https://foundry.bison-gray.ts.net:8317";
    description = "CLIProxyAPI hub that pools the Claude and Codex subscription logins.";
  };

  options.agentHarnesses.cliproxyHub.keyFile = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/.config/sops-nix/secrets/cliproxyapi_access_key";
    description = "File with the hub client access key. The default is the Home Manager sops-nix path.";
  };
}
