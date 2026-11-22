{
  config,
  lib,
  pkgs,
  ...
}: {
  # Only personal hosts reach the homelab Executor.
  options.agentHarnesses.executor.enable = lib.mkEnableOption "the personal Executor MCP server";

  options.agentHarnesses.executor.origin = lib.mkOption {
    type = lib.types.str;
    # Switch to hearth.bison-gray.ts.net:4443 in M8.
    default = "https://forge.bison-gray.ts.net:4443";
    description = "Origin of the personal Executor server.";
  };

  options.agentHarnesses.executor.url = lib.mkOption {
    type = lib.types.str;
    default = "${config.agentHarnesses.executor.origin}/mcp";
    description = "Personal Executor MCP endpoint for HTTP clients.";
  };

  options.agentHarnesses.executor.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.callPackage ./executor-package.nix {};
    description = "Executor CLI for personal MCP clients that use stdio.";
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

  options.agentHarnesses.cliproxyHub.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Route configured harnesses through the CLIProxyAPI hub instead of direct logins.";
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

  options.agentHarnesses.pstack.modelsFile = lib.mkOption {
    type = lib.types.path;
    default = ./shared/pstack-models.md;
    description = "t3-pstack model routing sheet installed to ~/.config/t3-pstack/models.md.";
  };
}
