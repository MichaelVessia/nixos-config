{
  pkgs,
  pkgs-unstable,
  inputs,
  enableFloCli,
  ...
}: let
  floai = inputs.floai or null;
  hasFloai = floai != null;
  floCli = floai.packages.${pkgs.system}.default;
in {
  # Hosts opt in with enableFloCli (flomac, forge, foundry). The floai input is
  # SAML-protected, so hosts without access leave it off.
  home.packages =
    pkgs.lib.optionals (enableFloCli && hasFloai) [floCli]
    ++ pkgs.lib.optionals enableFloCli [
      (pkgs-unstable.callPackage ./pup {}) # Datadog API CLI; needs newer rustc than 25.11 ships
    ];
}
