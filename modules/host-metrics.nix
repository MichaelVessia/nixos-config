{
  config,
  lib,
  pkgs,
  ...
}: {
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    validateConfigFile = true;
    settings = import ./host-metrics-settings.nix {
      inherit lib;
      hostName = config.networking.hostName;
    };
  };
}
