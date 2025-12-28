# fmcal - CLI calendar viewer
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
in {
  home.packages = [fmcal-pkg];
}
