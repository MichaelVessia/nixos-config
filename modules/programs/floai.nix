{
  pkgs,
  floai,
  ...
}: {
  home.packages = [floai.packages.${pkgs.system}.default];
}
