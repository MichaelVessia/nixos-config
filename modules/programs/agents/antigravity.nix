{
  config,
  lib,
  pkgs,
  ...
}: let
  mcpConfig = {
    mcpServers = lib.optionalAttrs config.agentHarnesses.executor.enable {
      executor = {
        serverUrl = config.agentHarnesses.executor.url;
      };
    };
  };

  mcpConfigFile = (pkgs.formats.json {}).generate "antigravity-mcp-config.json" mcpConfig;
in {
  home.file.".gemini/config/mcp_config.json".source = mcpConfigFile;

  home.activation.antigravityMcpConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for dir in "$HOME/.t3/userdata/providers/antigravity"/*/config; do
      [ -d "$dir" ] || continue
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -Dm644 "${mcpConfigFile}" "$dir/mcp_config.json"
    done
  '';
}
