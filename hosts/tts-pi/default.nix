{
  config,
  pkgs,
  lib,
  ...
}: {
  # Headless Pi - no desktop, minimal install

  # Only ext4/vfat needed, disable others to speed up builds
  boot.supportedFilesystems = {
    zfs = lib.mkForce false;
    btrfs = lib.mkForce false;
    xfs = lib.mkForce false;
    ntfs = lib.mkForce false;
    cifs = lib.mkForce false;
  };

  networking.hostName = "tts-pi";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone
  time.timeZone = "America/New_York";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # User account
  users.users.pi = {
    isNormalUser = true;
    extraGroups = ["wheel" "audio" "networkmanager"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r"
    ];
  };

  # Allow passwordless sudo for pi user
  security.sudo.wheelNeedsPassword = false;

  # Enable SSH (key auth only)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Enable flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # Accept unsigned paths for remote deploys
    trusted-users = ["root" "pi"];
    require-sigs = false;
  };

  # Allow unfree packages (for firmware)
  nixpkgs.config.allowUnfree = true;

  # Packages
  environment.systemPackages = with pkgs; [
    curl
    ffmpeg
    vim
    htop
  ];

  # Snapcast server
  services.snapserver = {
    enable = true;
    settings = {
      stream.source = [
        "pipe:///run/snapserver/fifo?name=default"
        "tcp://0.0.0.0:4953?name=tts"
      ];
      http = {
        enabled = true;
        doc_root = "${pkgs.snapcast}/share/snapserver/snapweb";
      };
    };
  };

  # Snapcast client (plays audio locally) - no NixOS module yet, use systemd
  systemd.services.snapclient = {
    description = "Snapcast Client";
    after = ["network.target" "snapserver.service" "sound.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      ExecStart = "${pkgs.snapcast}/bin/snapclient -h 127.0.0.1";
      Restart = "always";
      RestartSec = 5;
      User = "pi";
      Group = "audio";
    };
  };

  # TTS script
  environment.etc."tts/tts.sh" = {
    mode = "0755";
    text = ''
      #!/run/current-system/sw/bin/bash
      MESSAGE="$1"
      if [ -z "$MESSAGE" ]; then
          echo "Usage: $0 \"message to speak\""
          exit 1
      fi

      ENCODED=$(${pkgs.python3}/bin/python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$MESSAGE")
      URL="https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=$ENCODED"

      ${pkgs.curl}/bin/curl -s -A "Mozilla/5.0" "$URL" -o /tmp/tts.mp3
      ${pkgs.ffmpeg}/bin/ffmpeg -i /tmp/tts.mp3 -f s16le -ar 48000 -ac 2 - 2>/dev/null | tee /run/snapserver/fifo > /dev/null
    '';
  };

  # TTS HTTP server as a systemd service
  systemd.services.tts-server = {
    description = "TTS HTTP Server";
    after = ["network.target" "snapserver.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 /etc/tts/tts_server.py";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # TTS HTTP server script
  environment.etc."tts/tts_server.py" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env python3
      from http.server import HTTPServer, BaseHTTPRequestHandler
      import subprocess
      import json

      class TTSHandler(BaseHTTPRequestHandler):
          def do_POST(self):
              content_length = int(self.headers.get("Content-Length", 0))
              body = self.rfile.read(content_length).decode("utf-8")

              try:
                  data = json.loads(body)
                  message = data.get("message", "")
              except:
                  message = body

              if message:
                  subprocess.run(["/etc/tts/tts.sh", message])
                  self.send_response(200)
                  self.send_header("Content-type", "application/json")
                  self.end_headers()
                  self.wfile.write(json.dumps({"status": "ok"}).encode())
              else:
                  self.send_response(400)
                  self.end_headers()

          def log_message(self, format, *args):
              pass  # Suppress logging

      if __name__ == "__main__":
          server = HTTPServer(("0.0.0.0", 5000), TTSHandler)
          print("TTS server running on port 5000")
          server.serve_forever()
    '';
  };

  # Open firewall for TTS server and Snapcast
  networking.firewall = {
    allowedTCPPorts = [
      5000 # TTS HTTP server
      1704 # Snapcast stream
      1705 # Snapcast control
      1780 # Snapcast web UI
    ];
  };

  # Enable ALSA sound (for snapclient output via 3.5mm jack)
  hardware.enableAllFirmware = true;
  services.pipewire.enable = false;
  hardware.alsa.enable = true;

  system.stateVersion = "25.05";
}
