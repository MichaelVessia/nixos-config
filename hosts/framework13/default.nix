{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/desktop-system.nix
    ../../modules/host-metrics.nix
  ];
  # Push-only host agent: disable the Collector's default telemetry listener.
  services.opentelemetry-collector.settings.service.telemetry.metrics.level = "none";
  # Enable aarch64 emulation for cross-compiling Pi images
  boot.binfmt.emulatedSystems = ["aarch64-linux"];
  networking.hostName = "framework13"; # Define your hostname.

  services.pipewire = {
    wireplumber = {
      enable = true;
      extraConfig = {
        # Force duplex profile (output + input) for built-in audio
        "50-alsa-config" = {
          "monitor.alsa.rules" = [
            {
              matches = [{"device.name" = "alsa_card.pci-0000_00_1f.3";}];
              actions = {
                update-props = {
                  "api.acp.auto-profile" = false;
                  "device.profile" = "output:analog-stereo+input:analog-stereo";
                };
              };
            }
            {
              matches = [{"device.name" = "alsa_card.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00";}];
              actions = {
                update-props = {
                  "api.acp.auto-profile" = false;
                  "device.profile" = "input:analog-stereo-input";
                };
              };
            }
            {
              matches = [
                {
                  "node.name" = "alsa_output.usb-Focusrite_Scarlett_Solo_4th_Gen_S190NM15BB541C-00.HiFi__Line1__sink";
                }
              ];
              actions = {
                update-props = {
                  "node.disabled" = true;
                };
              };
            }
          ];
        };
      };
    };
  };
  # WirePlumber silently drops the built-in analog output profile when
  # /dev/snd/pcmC0D0p is busy during its card probe (happens at boot and
  # after suspend/resume), leaving only HDMI sinks and no speaker audio.
  # Until the boot-time holder is identified, log it and heal by forcing
  # a re-probe.
  #
  # If speakers ever go silent again:
  #   - Watchdog log (shows the healing + the culprit process name):
  #       journalctl --user -u analog-sink-watchdog
  #   - Manual heal (same thing the watchdog does):
  #       systemctl --user restart wireplumber
  #   - Check sinks (should list "Built-in Audio Analog Stereo"):
  #       wpctl status
  #   - If sink exists but still silent, check ALSA Master isn't muted:
  #       amixer -c 0 sset Master 100% unmute
  # Once the journal names the process holding pcmC0D0p, fix that at the
  # source and delete this watchdog.
  systemd.user.services.analog-sink-watchdog = {
    description = "Re-probe audio card when built-in analog sink is missing";
    after = ["wireplumber.service"];
    wantedBy = ["default.target"];
    path = [pkgs.pipewire pkgs.psmisc];
    script = ''
      sink=alsa_output.pci-0000_00_1f.3.analog-stereo
      while true; do
        sleep 15
        systemctl --user --quiet is-active wireplumber.service || continue
        pw-cli ls Node 2>/dev/null | grep -q "$sink" && continue
        echo "analog sink missing; holders of pcmC0D0p:"
        fuser -v /dev/snd/pcmC0D0p || true
        systemctl --user restart wireplumber.service
        sleep 30
      done
    '';
  };
  virtualisation.vmVariant = {
    # A test VM must not publish metrics under this physical laptop's identity.
    services.opentelemetry-collector.enable = lib.mkForce false;
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      qemu.options = [
        "-vga"
        "none"
        "-device"
        "virtio-vga-gl"
        "-display"
        "gtk,gl=on"
      ];
    };

    services.openssh.enable = true;
    users.users.michaelvessia = {
      initialPassword = "test";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r"
      ];
    };

    services.greetd.settings.initial_session = {
      command = "niri-session";
      user = "michaelvessia";
    };

    home-manager.users.michaelvessia.programs.niri.settings.spawn-at-startup = [
      {command = ["${pkgs.foot}/bin/foot"];}
    ];
  };
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
