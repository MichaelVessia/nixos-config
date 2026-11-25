{
  config,
  lib,
  pkgs,
  ...
}: let
  topology = config.homelab.topology;
  hostName = config.networking.hostName;
  mapleEndpoint = "http://127.0.0.1:${toString topology.services.maple.port}";
  unpollerTarget = "127.0.0.1:9130";
  unpollerConfig = (pkgs.formats.json {}).generate "unpoller.json" {
    unifi.defaults = {
      url = "https://${topology.network.gateway}";
      hash_pii = true;
      ssl_cert_paths = [./unifi.crt];
      timeout = "10s";
    };
    prometheus.http_listen = unpollerTarget;
    influxdb.disable = true;
    datadog.disable = true;
    poller.quiet = true;
  };
in {
  sops.secrets = {
    homelab_maple_env.restartUnits = ["opentelemetry-collector.service"];
    homelab_unpoller_env = {
      sopsFile = config.homelab.backups.sopsFile;
      restartUnits = ["unpoller.service"];
    };
  };

  systemd.services.unpoller = {
    description = "UniFi metrics exporter";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      DynamicUser = true;
      EnvironmentFile = config.sops.secrets.homelab_unpoller_env.path;
      ExecStart = "${lib.getExe' pkgs.unpoller "unpoller"} --config ${unpollerConfig}";
      Restart = "on-failure";
      RestartSec = "15s";
    };
  };

  systemd.services.opentelemetry-collector = {
    after = ["docker.service" "unpoller.service"];
    wants = ["docker.service" "unpoller.service"];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.homelab_maple_env.path;
      SupplementaryGroups = ["docker"];
    };
  };

  services.opentelemetry-collector.settings = {
    receivers = {
      docker_stats = {
        endpoint = "unix:///var/run/docker.sock";
        collection_interval = "60s";
        container_labels_to_metric_labels."com.docker.compose.service" = "compose.service";
      };
      "prometheus/unifi".config.scrape_configs = [
        {
          job_name = "unifi";
          scrape_interval = "60s";
          scrape_timeout = "25s";
          static_configs = [{targets = [unpollerTarget];}];
          metric_relabel_configs = [
            {
              source_labels = ["__name__"];
              regex = "unpoller_.*";
              action = "keep";
            }
          ];
        }
      ];
      journald = {
        directory = "/var/log/journal";
        journalctl_path = "${pkgs.systemd}/bin/journalctl";
        storage = "file_storage";
        convert_message_bytes = true;
        # Docker uses the journald driver. Keep the container name as the log service.
        operators = [
          {
            type = "add";
            field = "resource[\"host.name\"]";
            value = hostName;
          }
          {
            type = "add";
            field = "resource[\"service.name\"]";
            value = "${hostName}-journal";
          }
          {
            id = "container_service";
            type = "copy";
            from = "body.CONTAINER_NAME";
            to = "resource[\"service.name\"]";
            "if" = "body.CONTAINER_NAME != nil";
          }
          {
            id = "container_name";
            type = "copy";
            from = "body.CONTAINER_NAME";
            to = "attributes[\"container.name\"]";
            "if" = "body.CONTAINER_NAME != nil";
          }
          {
            id = "systemd_unit";
            type = "copy";
            from = "body._SYSTEMD_UNIT";
            to = "attributes[\"systemd.unit\"]";
            "if" = "body._SYSTEMD_UNIT != nil";
          }
          {
            type = "severity_parser";
            parse_from = "body.PRIORITY";
            "if" = "body.PRIORITY != nil";
            overwrite_text = true;
            mapping = {
              fatal = ["0" "1" "2"];
              error = "3";
              warn = "4";
              info = ["5" "6"];
              debug = "7";
            };
          }
          {
            id = "message";
            type = "copy";
            from = "body.MESSAGE";
            to = "body";
            "if" = "body.MESSAGE != nil";
          }
        ];
      };
    };

    processors = {
      "resource/docker".attributes = [
        {
          key = "host.name";
          value = hostName;
          action = "upsert";
        }
        {
          key = "service.name";
          value = "${hostName}-docker";
          action = "upsert";
        }
      ];
      "filter/journald".log_conditions = [
        ''log.attributes["container.name"] == "homelab-maple"''
        ''log.attributes["systemd.unit"] == "opentelemetry-collector.service"''
        ''IsMatch(log.body, "(GET|HEAD) /([[:alnum:]_-]+/)*(health|healthz|ready|readyz|healthcheck)(/[^ ]*)? HTTP/[0-9.]+[^0-9]*2[0-9]{2}([^0-9]|$)")''
      ];
    };

    extensions.file_storage.directory = ".";
    exporters.otlp_http = {
      endpoint = lib.mkForce mapleEndpoint;
      headers."x-maple-ingest-key" = "\${env:MAPLE_LOCAL_INGEST_KEY}";
    };
    service = {
      extensions = ["file_storage"];
      pipelines = {
        "metrics/docker" = {
          receivers = ["docker_stats"];
          processors = ["memory_limiter" "resource/docker" "batch"];
          exporters = ["otlp_http"];
        };
        "metrics/unifi" = {
          receivers = ["prometheus/unifi"];
          processors = ["memory_limiter" "batch"];
          exporters = ["otlp_http"];
        };
        logs = {
          receivers = ["journald"];
          processors = ["memory_limiter" "filter/journald" "batch"];
          exporters = ["otlp_http"];
        };
      };
    };
  };
}
