{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  codexUnwrapped = inputs.llm-agents.packages.${pkgs.system}.codex;

  # Codex starts a shared background server by default, which requires a
  # packaged install (codex-package.json) that the Nix package does not ship.
  codexPkg = pkgs.symlinkJoin {
    name = "codex-wrapped-${codexUnwrapped.version or "0"}";
    paths = [codexUnwrapped];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/codex --add-flags --no-daemon
    '';
  };
  sharedInstructions = builtins.readFile ./shared/instructions.md;
  # Codex has no include, so pstack's model rows go into AGENTS.md. The
  # session hook line stays only in the sheet.
  pstackSheet = builtins.readFile ./shared/pstack-models.md;
  pstackRows = lib.concatStringsSep "\n" (lib.filter (line: !(lib.hasPrefix "session hook:" line)) (lib.splitString "\n" pstackSheet));
  codexAgents = sharedInstructions + "\n" + pstackRows;

  codexConfig =
    {
      personality = "pragmatic";
      model = "gpt-6.1-sol";
      model_reasoning_effort = "medium";
      features.goals = true;
      tui = {
        status_line = ["model-with-reasoning" "current-dir" "git-branch" "context-used"];
      };
      mcp_servers = {
        executor = {
          url = config.agentHarnesses.executor.url;
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
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      marketplaces.flocasts = {
        source_type = "git";
        source = "git@github.com:flocasts/floai.git";
      };
      plugins."floai@flocasts".enabled = true;
    };

  codexConfigFile = (pkgs.formats.toml {}).generate "codex-config.toml" codexConfig;
in {
  config = {
    home.packages = [codexPkg];

    home.file.".codex/AGENTS.md".text = codexAgents;
    home.file.".codex/pstack-models.md".source = ./shared/pstack-models.md;

    home.activation =
      {
        codexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
          install -Dm644 ${codexConfigFile} "$HOME/.codex/config.toml"
        '';
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        codexMarketplaceFloai = lib.hm.dag.entryAfter ["codexConfig"] ''
          if [ ! -d "$HOME/.codex/plugins/cache/flocasts" ]; then
            PATH="${pkgs.git}/bin:${pkgs.openssh}/bin:$PATH" $DRY_RUN_CMD ${codexPkg}/bin/codex plugin marketplace add git@github.com:flocasts/floai.git || true
          fi
        '';
      };
  };
}
