{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [inputs.collie.packages.${pkgs.system}.collie];
}
