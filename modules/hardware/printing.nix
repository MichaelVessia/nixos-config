# Printing Configuration
{...}: {
  services.printing.enable = true;

  # ensure-printers runs at boot before network/printer is ready
  # Add network dependency and retry logic
  systemd.services.ensure-printers = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother_HL-L3270CDW";
        location = "Home";
        deviceUri = "ipp://192.168.1.138/ipp";
        model = "everywhere";
        ppdOptions = {
          PageSize = "Letter";
        };
      }
    ];
    ensureDefaultPrinter = "Brother_HL-L3270CDW";
  };
}
