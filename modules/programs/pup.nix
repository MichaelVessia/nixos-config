{
  pkgs,
  pkgs-unstable,
  enableFloCli,
  ...
}: {
  # Hosts opt in with enableFloCli (dev-machine, flomac, foundry).
  home.packages = pkgs.lib.optionals enableFloCli [
    (pkgs-unstable.callPackage ./pup {}) # Datadog API CLI; needs newer rustc than 25.11 ships
  ];
}
