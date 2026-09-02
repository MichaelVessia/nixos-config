{
  config,
  pkgs,
  ...
}: let
  sharedInstructions = builtins.readFile ./shared/instructions.md;
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    experimental.openTelemetry = true;
    model = "openai/gpt-5.5-fast";
    provider.openai.models."gpt-5.5-fast".options.reasoningEffort = "xhigh";
    mcp.executor = {
      type = "remote";
      url = config.agentHarnesses.executor.url;
      enabled = true;
    };
  };
  opencodeConfigFile = (pkgs.formats.json {}).generate "opencode.json" opencodeConfig;
in {
  config = {
    home.file.".config/opencode/AGENTS.md".text = sharedInstructions;
    home.file.".config/opencode/opencode.json".source = opencodeConfigFile;
  };
}
