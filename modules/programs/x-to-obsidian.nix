# X to Obsidian - background server for Chrome extension
#
# Secrets come from sops-nix (/run/secrets/ or ~/.config/sops-nix/secrets/).
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
  wrapper = pkgs.writeShellScript "x-to-obsidian-wrapper" ''
    SECRETS_DIR="/run/secrets"
    [ -d "$HOME/.config/sops-nix/secrets" ] && SECRETS_DIR="$HOME/.config/sops-nix/secrets"

    [ -f "$SECRETS_DIR/x_to_obsidian_vault_path" ] && export VAULT_PATH="$(cat "$SECRETS_DIR/x_to_obsidian_vault_path")"
    [ -f "$SECRETS_DIR/x_to_obsidian_llm_provider" ] && export LLM_PROVIDER="$(cat "$SECRETS_DIR/x_to_obsidian_llm_provider")"
    [ -f "$SECRETS_DIR/x_to_obsidian_google_api_key" ] && export GOOGLE_API_KEY="$(cat "$SECRETS_DIR/x_to_obsidian_google_api_key")"
    [ -f "$SECRETS_DIR/x_to_obsidian_anthropic_api_key" ] && export ANTHROPIC_API_KEY="$(cat "$SECRETS_DIR/x_to_obsidian_anthropic_api_key")"

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
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  }
