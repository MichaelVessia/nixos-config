{
  lib,
  hostName,
  isDarwin ? false,
}: {
  receivers.host_metrics = {
    collection_interval = "30s";
    scrapers =
      {
        cpu.metrics."system.cpu.utilization".enabled = true;
        memory.metrics."system.memory.utilization".enabled = true;
        filesystem.metrics."system.filesystem.utilization".enabled = true;
        disk = {};
        load = {};
        network = {};
        processes = lib.optionalAttrs isDarwin {
          # Created-process totals are supported only on Linux and OpenBSD.
          metrics."system.processes.created".enabled = false;
        };
      }
      # The Darwin paging backend exposes unpopulated swap fields as zero.
      # Omit unsupported paging measurements rather than report healthy swap.
      // lib.optionalAttrs (!isDarwin) {paging = {};};
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
        value = hostName;
        action = "upsert";
      }
      {
        key = "service.name";
        value = "${hostName}-host";
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
}
