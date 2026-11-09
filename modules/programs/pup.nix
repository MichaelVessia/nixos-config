{pkgs-unstable, ...}: {
  home.packages = [
    (pkgs-unstable.callPackage ./pup {}) # Datadog API CLI; needs newer rustc than 25.11 ships
  ];
}
