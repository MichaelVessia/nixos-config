{
  config,
  lib,
  pkgs,
  ...
}: let
  key = config.sops.secrets.sentinel_adguard_sync_ssh_key;
  syncPolicy = pkgs.writeShellApplication {
    name = "hearth-sync-sentinel-dns";
    runtimeInputs = [pkgs.openssh pkgs.yq-go];
    text = ''
      yq --output-format json 'pick([
        "schema_version", "dns", "filtering", "filters", "whitelist_filters",
        "user_rules", "clients", "querylog", "statistics"
      ])' /var/lib/AdGuardHome/AdGuardHome.yaml |
        ssh -T -F /dev/null -o BatchMode=yes -o ConnectTimeout=10 \
          -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${../sentinel/ssh-known-hosts} \
          -i "$CREDENTIALS_DIRECTORY/ssh-key" root@192.168.1.37
    '';
  };
in {
  sops.secrets.sentinel_adguard_sync_ssh_key.sopsFile = ../../secrets/homelab.yaml;
  systemd.services.sentinel-dns-sync = {
    description = "Sync the AdGuard Home DNS policy to sentinel";
    after = ["adguardhome.service" "network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      LoadCredential = "ssh-key:${key.path}";
      ExecStart = lib.getExe syncPolicy;
      TimeoutStartSec = "60s";
    };
  };
  systemd.timers.sentinel-dns-sync = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnActiveSec = "2min";
      OnUnitActiveSec = "10min";
    };
  };
}
