{ip}: let
  ucd = "1.3.6.1.4.1.2021";
  system = "1.3.6.1.4.1.6574.1";
  disk = "1.3.6.1.4.1.6574.2.1.1";
  raid = "1.3.6.1.4.1.6574.3.1.1";
  storage = "1.3.6.1.2.1.25.2.3.1";
  interfaces = "1.3.6.1.2.1.31.1.1.1";

  scalar = name: value: oid: {
    inherit oid;
    attributes = [{inherit name value;}];
  };
  column = names: oid: {
    inherit oid;
    attributes = map (name: {inherit name;}) names;
  };
  tableGauge = unit: names: oid: {
    inherit unit;
    gauge.value_type = "int";
    column_oids = [(column names oid)];
  };
in {
  endpoint = "udp://${ip}:161";
  collection_interval = "60s";
  version = "v3";
  security_level = "auth_priv";
  user = "\${env:SYNOLOGY_SNMP_USER}";
  auth_type = "SHA";
  auth_password = "\${env:SYNOLOGY_SNMP_AUTH_PASSWORD}";
  privacy_type = "AES";
  privacy_password = "\${env:SYNOLOGY_SNMP_PRIV_PASSWORD}";

  attributes = {
    "cpu.mode".enum = ["user" "system" "idle"];
    "load.period".enum = ["1m" "5m" "15m"];
    "memory.kind".enum = ["total" "available" "buffer" "cache"];
    "system.component".enum = ["system" "power" "system_fan" "cpu_fan"];
    "disk.name".oid = "${disk}.2";
    "disk.model".oid = "${disk}.3";
    "raid.name".oid = "${raid}.2";
    "storage.mount".oid = "${storage}.3";
    "network.interface.name".oid = "${interfaces}.1";
    "network.io.direction".enum = ["receive" "transmit"];
  };

  metrics = {
    "synology.cpu.utilization" = {
      unit = "%";
      gauge.value_type = "int";
      scalar_oids = [
        (scalar "cpu.mode" "user" "${ucd}.11.9.0")
        (scalar "cpu.mode" "system" "${ucd}.11.10.0")
        (scalar "cpu.mode" "idle" "${ucd}.11.11.0")
      ];
    };
    "synology.cpu.load_average" = {
      unit = "1";
      gauge.value_type = "double";
      # laLoadFloat exposes these values as numbers. laLoad returns strings.
      scalar_oids = [
        (scalar "load.period" "1m" "${ucd}.10.1.6.1")
        (scalar "load.period" "5m" "${ucd}.10.1.6.2")
        (scalar "load.period" "15m" "${ucd}.10.1.6.3")
      ];
    };
    "synology.memory.size" = {
      unit = "KiBy";
      gauge.value_type = "int";
      scalar_oids = [
        (scalar "memory.kind" "total" "${ucd}.4.5.0")
        (scalar "memory.kind" "available" "${ucd}.4.6.0")
        (scalar "memory.kind" "buffer" "${ucd}.4.14.0")
        (scalar "memory.kind" "cache" "${ucd}.4.15.0")
      ];
    };
    "synology.system.status" = {
      unit = "1";
      gauge.value_type = "int";
      scalar_oids = [
        (scalar "system.component" "system" "${system}.1.0")
        (scalar "system.component" "power" "${system}.3.0")
        (scalar "system.component" "system_fan" "${system}.4.1.0")
        (scalar "system.component" "cpu_fan" "${system}.4.2.0")
      ];
    };
    "synology.system.temperature" = {
      unit = "Cel";
      gauge.value_type = "int";
      scalar_oids = [{oid = "${system}.2.0";}];
    };
    "synology.disk.status" = tableGauge "1" ["disk.name" "disk.model"] "${disk}.5";
    "synology.disk.temperature" = tableGauge "Cel" ["disk.name" "disk.model"] "${disk}.6";
    "synology.raid.status" = tableGauge "1" ["raid.name"] "${raid}.3";
    "synology.raid.free" = tableGauge "By" ["raid.name"] "${raid}.4";
    "synology.raid.total" = tableGauge "By" ["raid.name"] "${raid}.5";
    "synology.storage.allocation_unit_size" = tableGauge "By" ["storage.mount"] "${storage}.4";
    "synology.storage.size" = tableGauge "{allocation_unit}" ["storage.mount"] "${storage}.5";
    "synology.storage.used" = tableGauge "{allocation_unit}" ["storage.mount"] "${storage}.6";
    "synology.network.io" = {
      unit = "By";
      sum = {
        aggregation = "cumulative";
        monotonic = true;
        value_type = "int";
      };
      column_oids = [
        {
          oid = "${interfaces}.6";
          attributes = [
            {name = "network.interface.name";}
            {
              name = "network.io.direction";
              value = "receive";
            }
          ];
        }
        {
          oid = "${interfaces}.10";
          attributes = [
            {name = "network.interface.name";}
            {
              name = "network.io.direction";
              value = "transmit";
            }
          ];
        }
      ];
    };
  };
}
