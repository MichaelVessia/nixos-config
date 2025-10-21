# Printing Configuration
{pkgs, ...}: {
  services.printing = {
    enable = true;
    drivers = [pkgs.brlaser];
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
