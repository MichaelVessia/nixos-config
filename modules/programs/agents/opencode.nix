{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # opencode.json is shared by every host, so the personal Executor comes from
  # OPENCODE_CONFIG_CONTENT, which OpenCode merges into it.
  executorConfig = builtins.toJSON {
    mcp.servers.executor = {
      type = "remote";
      url = config.agentHarnesses.executor.url;
    };
  };
  opencodePkg = inputs.llm-agents.packages.${pkgs.system}.opencode2;
  opencodeWrapped = pkgs.symlinkJoin {
    name = "opencode2-wrapped-${opencodePkg.version or "0"}";
    paths = [opencodePkg];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/opencode2 \
        --set OPENCODE_EXECUTOR_FLOSPORTS_URL "${config.agentHarnesses.executorFlosports.url}" \
        --set OPENCODE_FIGMA_URL "${config.agentHarnesses.figma.url}" ${
        lib.optionalString config.agentHarnesses.executor.enable
        "--set OPENCODE_CONFIG_CONTENT ${lib.escapeShellArg executorConfig}"
      }
    '';
  };
  sharedInstructions = builtins.readFile ./shared/instructions.md;
  opencodeDir = "${config.home.homeDirectory}/nixos-config/modules/programs/agents/opencode";
in {
  config = {
    home.packages = [opencodeWrapped];

    home.file.".config/opencode/AGENTS.md".text = sharedInstructions;

    # Keep OpenCode's server and terminal-client settings writable while
    # recording changes made through the CLI/TUI in the repository. OpenCode 2
    # follows these symlinks when updating either file.
    home.file.".config/opencode/opencode.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opencodeDir}/opencode.json";
    home.file.".config/opencode/cli.json".source =
      config.lib.file.mkOutOfStoreSymlink "${opencodeDir}/cli.json";
  };
}
