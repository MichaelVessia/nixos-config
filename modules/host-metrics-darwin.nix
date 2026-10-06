{
  config,
  lib,
  pkgs,
  ...
}: let
  package = pkgs.opentelemetry-collector-contrib;
  settings = import ./host-metrics-settings.nix {
    inherit lib;
    hostName = config.networking.hostName;
    isDarwin = true;
  };
  generatedConfig = (pkgs.formats.yaml {}).generate "host-metrics.yaml" (
    settings
    // {
      # This agent only pushes metrics; do not open the default telemetry listener.
      service = settings.service // {telemetry.metrics.level = "none";};
    }
  );
  configFile = pkgs.runCommandLocal "host-metrics.yaml" {inherit generatedConfig;} ''
    cp "$generatedConfig" "$out"
    ${lib.getExe package} validate --config="file:$out"
  '';
in {
  environment.etc."otelcol-host-metrics.yaml".source = configFile;
  environment.systemPackages = [package];

  launchd.daemons.opentelemetry-collector = {
    # gopsutil invokes the macOS netstat/ifconfig tools for network scrapes.
    environment.PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
    command = "${lib.getExe package} --config=file:${configFile}";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/var/log/otelcol-host-metrics.log";
      StandardErrorPath = "/var/log/otelcol-host-metrics.log";
    };
  };
}
