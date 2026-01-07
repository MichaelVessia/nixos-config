{
  pkgs,
  subq,
  ...
}: {
  home.packages = [
    subq.packages.${pkgs.system}.subq
    subq.packages.${pkgs.system}.subq-cli
  ];
}
