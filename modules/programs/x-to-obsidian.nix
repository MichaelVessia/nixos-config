# X to Obsidian - background server for Chrome extension
#
# Requires ~/.secrets.env with:
#   X_TO_OBSIDIAN_VAULT_PATH=/path/to/your/obsidian/vault
#   X_TO_OBSIDIAN_LLM_PROVIDER=google  # or "anthropic"
#   X_TO_OBSIDIAN_GOOGLE_API_KEY=xxx   # or X_TO_OBSIDIAN_ANTHROPIC_API_KEY
#
# Commands:
#   systemctl --user status x-to-obsidian   # check status
#   systemctl --user restart x-to-obsidian  # restart
#   systemctl --user stop x-to-obsidian     # stop
#   journalctl --user -u x-to-obsidian -f   # tail logs
{
  lib,
  pkgs,
  x-to-obsidian,
  ...
}: let
  x-to-obsidian-pkg = x-to-obsidian.packages.${pkgs.system}.default;
  # Wrapper script that maps prefixed env vars to what the app expects
  wrapper = pkgs.writeShellScript "x-to-obsidian-wrapper" ''
    export VAULT_PATH="''${X_TO_OBSIDIAN_VAULT_PATH}"
    export LLM_PROVIDER="''${X_TO_OBSIDIAN_LLM_PROVIDER}"
    export GOOGLE_API_KEY="''${X_TO_OBSIDIAN_GOOGLE_API_KEY:-}"
    export ANTHROPIC_API_KEY="''${X_TO_OBSIDIAN_ANTHROPIC_API_KEY:-}"
    exec ${x-to-obsidian-pkg}/bin/x-to-obsidian
  '';
in
  lib.mkIf pkgs.stdenv.isLinux {
    systemd.user.services.x-to-obsidian = {
      Unit = {
        Description = "X to Obsidian Server";
        After = ["network.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${wrapper}";
        Restart = "on-failure";
        EnvironmentFile = "%h/.secrets.env";
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  }
