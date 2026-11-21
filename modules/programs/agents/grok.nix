# When the CLIProxyAPI hub is enabled, Grok Build sends every request through
# the hub so the xAI subscription login lives only on the hub, and reads
# ~/.claude through its Claude compatibility layer for skills, CLAUDE.md, MCP
# servers, and hooks.
#
# On personal hosts (cliproxyHub.enable = false), Grok authenticates directly
# to xAI (`grok login`), disables Claude compatibility so stale ~/.claude files
# cannot leak work config, and uses native ~/.grok/AGENTS.md and MCP entries.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hub = config.agentHarnesses.cliproxyHub;
  toml = pkgs.formats.toml {};
  sharedInstructions = builtins.readFile ./shared/instructions.md;
  model = "grok-4.7";
  helperModel = "grok-4.7-build-fast";

  grokConfig =
    {
      compat =
        {
          cursor = {
            skills = false;
            rules = false;
            agents = false;
            mcps = false;
            hooks = false;
          };
        }
        // lib.optionalAttrs (!hub.enable) {
          claude = {
            skills = false;
            rules = false;
            agents = false;
            mcps = false;
            hooks = false;
          };
        };
    }
    // lib.optionalAttrs hub.enable {
      endpoints.models_base_url = "${hub.url}/v1";
      # Grok sends this command's output as the bearer token.
      auth.auth_provider_command = "${pkgs.coreutils}/bin/cat ${hub.keyFile}";
      # Unset helper models fall back to models from the hub's list, which also
      # holds the Claude and Codex subscriptions.
      models = {
        default = model;
        image_description = model;
        session_summary = helperModel;
        prompt_suggestion = helperModel;
        web_search = helperModel;
      };
    }
    // lib.optionalAttrs (!hub.enable && config.agentHarnesses.executor.enable) {
      mcp_servers.executor = {
        url = config.agentHarnesses.executor.url;
        enabled = true;
      };
    };
in {
  home.packages = [inputs.llm-agents.packages.${pkgs.system}.grok];

  home.file =
    {
      ".grok/config.toml".source = toml.generate "grok-config.toml" grokConfig;
    }
    // lib.optionalAttrs (!hub.enable) {
      ".grok/AGENTS.md".text = sharedInstructions;
    };
}
