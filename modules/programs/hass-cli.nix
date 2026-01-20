# hass-cli - CLI for Home Assistant
#
# Requires ~/.secrets.env with:
#   HASS_SERVER=http://homeassistant.local:8123
#   HASS_TOKEN=your-long-lived-access-token
#
# Commands:
#   hass-cli state list          # list all entities
#   hass-cli state get <entity>  # get entity state
#   hass-cli service call <svc>  # call a service
#   hass-cli --help              # help
{pkgs, ...}: let
  wrapper = pkgs.writeShellScriptBin "hass-cli" ''
    set -a
    source "$HOME/.secrets.env"
    set +a
    exec ${pkgs.home-assistant-cli}/bin/hass-cli "$@"
  '';
in {
  home.packages = [wrapper];
}
