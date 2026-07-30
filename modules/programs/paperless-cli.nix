# paperless-cli - CLI for Paperless-ngx document management
#
# Requires ~/.secrets.env with:
#   PAPERLESS_URL=https://paperless.example.com
#   PAPERLESS_TOKEN=your-api-token
#
# Commands:
#   paperless-cli search "query"  # search documents
#   paperless-cli --help          # help
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  paperless-cli-pkg = inputs.paperless-cli.packages.${pkgs.system}.default;
  wrapper = pkgs.writeShellScriptBin "paperless-cli" ''
    set -a
    source "$HOME/.secrets.env"
    set +a
    exec ${paperless-cli-pkg}/bin/paperless-cli "$@"
  '';
in {
  home.packages = lib.optionals pkgs.stdenv.isLinux [wrapper];
}
