{
  config,
  pkgs,
  ...
}: {
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    validateConfigFile = true;
    settings = {
      receivers.host_metrics = {
        collection_interval = "30s";
        scrapers = {
          cpu.metrics."system.cpu.utilization".enabled = true;
          memory.metrics."system.memory.utilization".enabled = true;
          filesystem.metrics."system.filesystem.utilization".enabled = true;
          disk = {};
          load = {};
          network = {};
          paging = {};
          processes = {};
        };
      };
      processors = {
        memory_limiter = {
          check_interval = "1s";
          limit_mib = 192;
          spike_limit_mib = 48;
        };
        resourcedetection = {
          detectors = ["system"];
          timeout = "2s";
          override = false;
          system = {
            hostname_sources = ["os"];
            resource_attributes."host.id".enabled = true;
          };
        };
        resource.attributes = [
          {
            key = "host.name";
            value = config.networking.hostName;
            action = "upsert";
          }
          {
            key = "service.name";
            value = "${config.networking.hostName}-host";
            action = "upsert";
          }
        ];
        batch = {
          timeout = "10s";
          send_batch_size = 1024;
        };
      };
      # Private LAN ingestion is source-allowlisted on SigNoz CT 124.
      exporters.otlp_grpc = {
        endpoint = "192.168.1.10:4317";
        tls.insecure = true;
      };
      service.pipelines.metrics = {
        receivers = ["host_metrics"];
        processors = ["memory_limiter" "resourcedetection" "resource" "batch"];
        exporters = ["otlp_grpc"];
      };
    };
  };
}
