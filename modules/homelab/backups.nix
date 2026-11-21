{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  backupsCfg = cfg.backups;
  nasBackupMount = cfg.topology.nas.backupMount.mountPoint;
  usesNasBackupMount = lib.hasPrefix nasBackupMount backupsCfg.repository;

  healthcheckPing = pkgs.writeShellApplication {
    name = "homelab-restic-healthcheck";
    runtimeInputs = [pkgs.coreutils pkgs.curl];
    text = ''
      mode="''${1:-finish}"
      url_file="${config.sops.secrets.homelab_restic_healthchecks_url.path}"

      if [ ! -r "$url_file" ]; then
        exit 0
      fi

      base_url="$(tr -d '\r\n' < "$url_file")"
      base_url="''${base_url%/}"
      if [ -z "$base_url" ]; then
        exit 0
      fi

      case "$mode" in
        start)
          target="$base_url/start"
          ;;
        finish)
          if [ "''${SERVICE_RESULT:-}" = "success" ]; then
            target="$base_url"
          else
            target="$base_url/fail"
          fi
          ;;
        *)
          exit 0
          ;;
      esac

      printf 'url = "%s"\n' "$target" | curl -fsS -m 10 --retry 3 -K - >/dev/null || true
    '';
  };

  prepareScript = pkgs.writeShellApplication {
    name = "homelab-restic-prepare";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux];
    text =
      lib.optionalString backupsCfg.healthchecks.enable ''
        ${lib.getExe healthcheckPing} start
      ''
      + lib.optionalString usesNasBackupMount ''
        # Trigger systemd automount and refuse to write into an unmounted local directory.
        ls "${nasBackupMount}" >/dev/null 2>&1 || true
        if ! mountpoint -q "${nasBackupMount}"; then
          echo "ERROR: ${nasBackupMount} is not mounted; refusing to write restic repo to local disk." >&2
          exit 1
        fi
      '';
  };
in {
  options.homelab.backups = {
    enable = lib.mkEnableOption "homelab restic backups to Synology NAS";

    repository = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.topology.nas.backupMount.mountPoint}/homelab-restic";
      description = "Target restic repository path on the Synology backup mount.";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Filesystem paths included in the homelab restic backup.";
    };

    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/homelab.yaml;
      description = "Encrypted sops file holding homelab backup secrets.";
    };

    healthchecks.enable = lib.mkEnableOption "Healthchecks.io pings for homelab restic backups";
  };

  config = lib.mkIf (cfg.enable && backupsCfg.enable) {
    homelab.backups.paths = ["/var/lib/homelab-backup-canary"];

    systemd.tmpfiles.rules = [
      "d /var/lib/homelab-backup-canary 0750 root root -"
      "f+ /var/lib/homelab-backup-canary/README.txt 0640 root root - homelab-restic-canary\\n"
    ];

    sops.secrets =
      {
        homelab_restic_password = {
          sopsFile = backupsCfg.sopsFile;
          owner = "root";
          mode = "0400";
        };
      }
      // lib.optionalAttrs backupsCfg.healthchecks.enable {
        homelab_restic_healthchecks_url = {
          sopsFile = backupsCfg.sopsFile;
          owner = "root";
          mode = "0400";
        };
      };

    services.restic.backups.homelab = {
      initialize = true;
      repository = backupsCfg.repository;
      passwordFile = config.sops.secrets.homelab_restic_password.path;
      paths = backupsCfg.paths;
      timerConfig = {
        OnCalendar = "03:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
      pruneOpts = [
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 6"
      ];
      backupPrepareCommand = lib.mkIf (backupsCfg.healthchecks.enable || usesNasBackupMount) (lib.getExe prepareScript);
    };

    systemd.services.restic-backups-homelab = lib.mkIf backupsCfg.healthchecks.enable {
      serviceConfig.ExecStopPost = ["-${lib.getExe healthcheckPing} finish"];
    };
  };
}
