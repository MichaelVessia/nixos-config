# Grok Build sends every request through the CLIProxyAPI hub, so the xAI
# subscription login lives only on the hub and clients need no `grok login`.
#
# Grok reads ~/.claude through its Claude compatibility layer: skills,
# CLAUDE.md, MCP servers from ~/.claude.json, and hooks.
{
  config,
  pkgs,
  inputs,
  ...
}: let
  hub = config.agentHarnesses.cliproxyHub;
  toml = pkgs.formats.toml {};
  model = "grok-4.7";
  helperModel = "grok-4.7-build-fast";
in {
  home.packages = [inputs.llm-agents.packages.${pkgs.system}.grok];

  home.file.".grok/config.toml".source = toml.generate "grok-config.toml" {
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
    compat.cursor = {
      skills = false;
      rules = false;
      agents = false;
      mcps = false;
      hooks = false;
    };
  };
}
