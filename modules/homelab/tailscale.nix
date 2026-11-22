{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  tsCfg = cfg.tailscale;
  serveExecutorScript = pkgs.writeShellApplication {
    name = "homelab-tailscale-serve";
    runtimeInputs = [pkgs.coreutils pkgs.jq config.services.tailscale.package];
    text = ''
      for _ in $(seq 1 30); do
        if tailscale status --json 2>/dev/null | jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done
      tailscale serve --bg --https=${toString tsCfg.serveExecutor.httpsPort} \
        "http://${cfg.hostIp}:${toString cfg.topology.services.executor.port}"
    '';
  };
in {
  options.homelab.tailscale = {
    enable = lib.mkEnableOption "homelab Tailscale subnet router and exit node";

    serveExecutor = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.apps.enable;
        description = "Declaratively publish Executor over Tailscale Serve on HTTPS.";
      };

      httpsPort = lib.mkOption {
        type = lib.types.port;
        default = 4443;
        description = "Tailscale Serve HTTPS port for Executor.";
      };
    };

    autoJoin = {
      enable = lib.mkEnableOption "unattended Tailscale join via sops-encrypted OAuth client secret";

      tag = lib.mkOption {
        type = lib.types.str;
        default = "tag:homelab-router";
        description = "ACL tag advertised on unattended join so Tailscale autoApprovers approve routes and exit node.";
      };
    };
  };

  config = lib.mkIf (cfg.enable && tsCfg.enable) {
    sops.secrets = lib.mkIf tsCfg.autoJoin.enable {
      homelab_tailscale_oauth_secret = {
        sopsFile = cfg.backups.sopsFile;
        owner = "root";
        mode = "0400";
      };
    };

    services.tailscale =
      {
        # Override the desktop module's client routing mode.
        useRoutingFeatures = lib.mkForce "server";
        extraSetFlags = [
          "--advertise-routes=${cfg.topology.network.lanSubnet}"
          "--advertise-exit-node"
        ];
      }
      // lib.optionalAttrs tsCfg.autoJoin.enable {
        authKeyFile = config.sops.secrets.homelab_tailscale_oauth_secret.path;
        authKeyParameters = {
          ephemeral = false;
          preauthorized = true;
        };
        extraUpFlags = [
          "--advertise-tags=${tsCfg.autoJoin.tag}"
          "--advertise-routes=${cfg.topology.network.lanSubnet}"
          "--advertise-exit-node"
        ];
      };

    systemd.services.homelab-tailscale-serve = lib.mkIf tsCfg.serveExecutor.enable {
      description = "Publish homelab Executor over Tailscale Serve";
      after =
        ["tailscaled.service" "network-online.target"]
        ++ lib.optionals tsCfg.autoJoin.enable ["tailscaled-autoconnect.service"];
      wants = ["tailscaled.service" "network-online.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe serveExecutorScript;
      };
    };
  };
}
