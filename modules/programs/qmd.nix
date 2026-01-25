# qmd - local semantic search for docs/notes
#
# Commands:
#   qmd index <dir>   # index a directory
#   qmd search <q>    # search indexed content
#   qmd -h            # help
{
  pkgs,
  qmd,
  ...
}: {
  home.packages = [qmd.packages.${pkgs.system}.default];
}
