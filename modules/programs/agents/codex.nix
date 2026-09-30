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
  codexAgents = sharedInstructions;

  pstackPlugin = inputs.pstack + "/plugins/pstack";
  pstackVersion = (lib.importJSON (pstackPlugin + "/.codex-plugin/plugin.json")).version;
  pstackPromptNames = lib.attrNames (builtins.readDir (pstackPlugin + "/.codex-plugin/prompts"));

  # recursiveUpdate keeps the shared marketplaces and plugins beside the
  # Darwin-only ones.
  codexConfig =
    lib.recursiveUpdate
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
      marketplaces.pstack-claude = {
        source_type = "local";
        source = "${inputs.pstack}";
      };
      # The SessionStart routing hook stays untrusted, so it does not run,
      # until Michael decides on automatic routing.
      plugins."pstack@pstack-claude".enabled = true;
    }
    (lib.optionalAttrs pkgs.stdenv.isDarwin {
      marketplaces.flocasts = {
        source_type = "git";
        source = "git@github.com:flocasts/floai.git";
      };
      plugins."floai@flocasts".enabled = true;
    });

  codexConfigFile = (pkgs.formats.toml {}).generate "codex-config.toml" codexConfig;
in {
  config = {
    home.packages = [codexPkg];

    home.file =
      {
        ".codex/AGENTS.md".text = codexAgents;
      }
      // lib.listToAttrs (map (name: {
          name = ".codex/prompts/${name}";
          value.source = pstackPlugin + "/.codex-plugin/prompts/${name}";
        })
        pstackPromptNames);

    home.activation =
      {
        codexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
          install -Dm644 ${codexConfigFile} "$HOME/.codex/config.toml"
        '';
        # Codex loads plugins only from its cache, so copy the pinned version
        # once from the declared local marketplace.
        codexPluginPstack = lib.hm.dag.entryAfter ["codexConfig"] ''
          if [ ! -d "$HOME/.codex/plugins/cache/pstack-claude/pstack/${pstackVersion}" ]; then
            $DRY_RUN_CMD ${codexPkg}/bin/codex plugin add pstack@pstack-claude || true
          fi
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
