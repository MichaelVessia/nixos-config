{
  config,
  lib,
  ...
}: let
  cfg = config.homelab;
in {
  options.homelab.tailscale.enable = lib.mkEnableOption "homelab Tailscale subnet router and exit node";

  config = lib.mkIf (cfg.enable && cfg.tailscale.enable) {
    services.tailscale = {
      # Override the desktop module's client routing mode.
      useRoutingFeatures = lib.mkForce "server";
      extraSetFlags = [
        "--advertise-routes=${cfg.topology.network.lanSubnet}"
        "--advertise-exit-node"
      ];
    };
  };
}
