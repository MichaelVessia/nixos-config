{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  backupsCfg = cfg.backups;
  resticBackup = config.services.restic.backups.homelab;
  nasBackupMount = cfg.topology.nas.backupMount.mountPoint;
  usesNasBackupMount = backupsCfg.repository == nasBackupMount || lib.hasPrefix "${nasBackupMount}/" backupsCfg.repository;

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

  heartbeatPing = pkgs.writeShellApplication {
    name = "homelab-heartbeat-ping";
    runtimeInputs = [pkgs.coreutils pkgs.curl];
    text = ''
      url_file="${config.sops.secrets.homelab_heartbeat_healthchecks_url.path}"
      if [ ! -r "$url_file" ]; then
        exit 0
      fi
      target="$(tr -d '\r\n' < "$url_file")"
      target="''${target%/}"
      if [ -z "$target" ]; then
        exit 0
      fi
      printf 'url = "%s"\n' "$target" | curl -fsS -m 10 --retry 3 -K - >/dev/null
    '';
  };

  requireNasBackupMount = pkgs.writeShellApplication {
    name = "homelab-restic-require-nas";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux];
    text = ''
      stat "${nasBackupMount}/." >/dev/null 2>&1 || true
      if ! findmnt --mountpoint "${nasBackupMount}" --types nfs,nfs4 >/dev/null; then
        echo "ERROR: ${nasBackupMount} is not mounted over NFS." >&2
        exit 1
      fi
    '';
  };

  prepareScript = pkgs.writeShellApplication {
    name = "homelab-restic-prepare";
    runtimeInputs = [pkgs.coreutils pkgs.docker pkgs.gnugrep];
    text =
      lib.optionalString backupsCfg.healthchecks.enable ''
        ${lib.getExe healthcheckPing} start
      ''
      + lib.optionalString usesNasBackupMount ''
        ${lib.getExe requireNasBackupMount}
      ''
      + ''
        dump_pg() {
          local container="$1" user="$2" db="$3" out="$4"
          if docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -qx true; then
            mkdir -p /opt/homelab/backups
            chmod 0700 /opt/homelab/backups
            umask 077
            docker exec "$container" pg_dump -Fc --no-owner --no-privileges -U "$user" "$db" > "$out.tmp"
            mv -f "$out.tmp" "$out"
          fi
        }
        dump_pg homelab-immich-db immich immich /opt/homelab/backups/immich.dump
        dump_pg homelab-freshrss-db freshrss_usr freshrss /opt/homelab/backups/freshrss.dump
        dump_pg homelab-paperless-db paperless paperless /opt/homelab/backups/paperless.dump
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
    heartbeat.enable = lib.mkEnableOption "5-minute Healthchecks.io host heartbeat timer";
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
      }
      // lib.optionalAttrs backupsCfg.heartbeat.enable {
        homelab_heartbeat_healthchecks_url = {
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
      extraBackupArgs = [
        "--exclude=/.snapshots"
        "--exclude=/opt/.snapshots"
        "--exclude=/var/lib/.snapshots"
        "--exclude=/opt/homelab/immich/postgres"
        "--exclude=/opt/homelab/freshrss/postgres"
        "--exclude=/opt/homelab/paperless/postgres"
      ];
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

    systemd.services.restic-check-homelab = {
      description = "Check the homelab Restic repository";
      after = ["network-online.target" "restic-backups-homelab.service"];
      wants = ["network-online.target"];
      environment = {
        RESTIC_REPOSITORY = resticBackup.repository;
        RESTIC_PASSWORD_FILE = resticBackup.passwordFile;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = lib.mkIf usesNasBackupMount (lib.getExe requireNasBackupMount);
        ExecStart = "${lib.getExe resticBackup.package} --retry-lock 1h check --read-data-subset=5%%";
      };
    };

    systemd.timers.restic-check-homelab = {
      description = "Monthly homelab Restic repository check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-01 05:00:00";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    systemd.services.homelab-heartbeat = lib.mkIf backupsCfg.heartbeat.enable {
      description = "Ping Healthchecks.io host heartbeat";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe heartbeatPing;
      };
    };

    systemd.timers.homelab-heartbeat = lib.mkIf backupsCfg.heartbeat.enable {
      description = "Periodic Healthchecks.io host heartbeat";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "5m";
        AccuracySec = "15s";
      };
    };
  };
}
