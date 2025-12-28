# fmcal - CLI calendar viewer
#
# Requires ~/.secrets.env with:
#   FMCAL_USERNAME=your@email.com
#   FMCAL_PASSWORD=your-app-password
#
# Commands:
#   fmcal          # show today's events
#   fmcal -h       # help
{
  pkgs,
  fmcal,
  ...
}: let
  fmcal-pkg = fmcal.packages.${pkgs.system}.default;
  wrapper = pkgs.writeShellScriptBin "fmcal" ''
    set -a
    source "$HOME/.secrets.env"
    set +a
    exec ${fmcal-pkg}/bin/fmcal "$@"
  '';
in {
  home.packages = [wrapper];
}
