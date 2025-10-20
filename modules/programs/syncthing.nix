{
  config,
  pkgs,
  ...
}: {
  # Syncthing - continuous file synchronization
  # Web UI: http://localhost:8384
  # Note: You'll need to pair this device with your other devices through the web UI
  # by exchanging device IDs and configuring shared folders
  services.syncthing = {
    enable = true;
    tray.enable = true; # Enable system tray icon
  };
}
