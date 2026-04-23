{
  lib,
  pkgs,
  ...
}: let
  sharedInstructions = builtins.readFile ./shared/instructions.md;

  codexConfig = {
    personality = "pragmatic";
    model = "gpt-5.5";
    model_reasoning_effort = "xhigh";
    tui = {
      status_line = ["model-with-reasoning" "current-dir" "git-branch" "context-used"];
    };
    mcp_servers = {
      atlassian = {
        url = "https://mcp.atlassian.com/v1/mcp";
      };
    };
    otel = {
      environment = "dev";
      log_user_prompt = false;
      exporter = {
        otlp-http = {
          endpoint = "https://http-intake.logs.datadoghq.com/v1/logs";
          protocol = "binary";
          headers = {
            "dd-api-key" = "$" + "{DD_TELEMETRY_API_KEY}";
          };
        };
      };
      trace_exporter = {
        otlp-http = {
          endpoint = "https://otlp.datadoghq.com/v1/traces";
          protocol = "binary";
          headers = {
            "dd-api-key" = "$" + "{DD_TELEMETRY_API_KEY}";
          };
        };
      };
    };
  };

  codexConfigFile = (pkgs.formats.toml {}).generate "codex-config.toml" codexConfig;
in {
  config = {
    home.file.".codex/AGENTS.md".text = sharedInstructions;

    home.activation.codexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      install -Dm644 ${codexConfigFile} "$HOME/.codex/config.toml"
    '';
  };
}
