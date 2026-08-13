{
  pkgs,
  inputs,
  ...
}: let
  floai = inputs.floai or null;
  hasFloai = floai != null;
  floCli = floai.packages.${pkgs.system}.default;
in {
  # flo-cli is only intended for use on flomac (darwin). The private floai
  # input is supplied by hosts/flomac/flake.nix so other hosts can update the
  # root flake without fetching the SAML-protected repository.
  home.packages = pkgs.lib.optionals (pkgs.stdenv.isDarwin && hasFloai) [floCli];
}
