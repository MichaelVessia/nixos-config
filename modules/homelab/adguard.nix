{
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
  dnsPort = cfg.topology.services.adguard.dnsPort;
  webHost = "127.0.0.1";
  webPort = cfg.topology.services.adguard.port;
in {
  options.homelab.adguard.enable = lib.mkEnableOption "homelab DNS server (AdGuard Home)";

  config = lib.mkIf (cfg.enable && cfg.adguard.enable) {
    services.adguardhome = {
      enable = true;
      host = webHost;
      port = webPort;
      mutableSettings = true;
      openFirewall = false;
      # The NixOS host and port options only generate settings when Nix manages the YAML.
      extraArgs = ["--web-addr" "${webHost}:${toString webPort}"];
    };

    networking.firewall = {
      allowedTCPPorts = [dnsPort];
      allowedUDPPorts = [dnsPort];
    };

    homelab.backups.paths = ["/var/lib/AdGuardHome"];
  };
}
