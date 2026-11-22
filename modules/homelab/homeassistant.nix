{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.homeassistant;
  inherit (lib) escapeShellArg escapeShellArgs mkOption types;
  ovmf = pkgs.OVMF.override {fdSize4MB = true;};
  qmpSocket = "/run/homelab-haos.qmp";
  guestRoute = escapeShellArg "${cfg.guestIp}/32";
  usbArgs =
    lib.concatMap (device: [
      "-device"
      "usb-host,bus=xhci.0,vendorid=0x${device.vendorId},productid=0x${device.productId}"
    ])
    cfg.usbDevices;
  qemuPath = lib.replaceStrings [","] [",,"];
  cleanup = ''
    ip route del ${guestRoute} dev ha-host0 2>/dev/null || true
    ip link del ha-tap0 2>/dev/null || true
    ip link del ha-host0 2>/dev/null || true
    rm -f ${qmpSocket}
  '';
in {
  options.homelab.homeassistant = {
    enable = lib.mkEnableOption "Home Assistant OS QEMU/KVM virtual machine";

    diskPath = mkOption {
      type = types.str;
      default = "/var/lib/homelab/haos/haos.raw";
      description = "Path to the HAOS disk image.";
    };

    diskFormat = mkOption {
      type = types.enum ["raw" "qcow2"];
      default = "raw";
      description = "Format of the HAOS disk image.";
    };

    efiVarsPath = mkOption {
      type = types.str;
      default = "/var/lib/homelab/haos/ovmf-vars.fd";
      description = "Path to the writable OVMF variables image.";
    };

    memoryMb = mkOption {
      type = types.int;
      default = 4096;
      description = "Guest memory in MiB.";
    };

    vcpus = mkOption {
      type = types.int;
      default = 2;
      description = "Number of virtual CPUs.";
    };

    parentInterface = mkOption {
      type = types.str;
      description = "Host Ethernet interface for macvtap L2 LAN attachment, e.g. enp5s0 on forge.";
    };

    macAddress = mkOption {
      type = types.str;
      default = "02:F4:AD:5F:59:6D";
      description = "MAC address of the HAOS network interface.";
    };

    guestIp = mkOption {
      type = types.str;
      default = "192.168.1.227";
      description = "LAN IPv4 address assigned to HAOS by DHCP.";
    };

    hostShimIp = mkOption {
      type = types.str;
      default = "192.168.1.2";
      description = "Unused LAN IP outside DHCP range for the host macvlan shim so local Caddy can reach the macvtap guest.";
    };

    usbDevices = mkOption {
      type = types.listOf (types.submodule {
        options = {
          vendorId = mkOption {
            type = types.str;
            description = "Four-digit hexadecimal USB vendor ID without the 0x prefix.";
          };
          productId = mkOption {
            type = types.str;
            description = "Four-digit hexadecimal USB product ID without the 0x prefix.";
          };
        };
      });
      default = [];
      description = "Host USB devices to pass through to HAOS.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = ["macvtap"];
    systemd.tmpfiles.rules = ["d /var/lib/homelab/haos 0755 root root -"];

    services.udev.extraRules = ''
      SUBSYSTEM=="net", KERNEL=="ha-host0|ha-tap0", ENV{NM_UNMANAGED}="1"
    '';

    systemd.services.homelab-homeassistant = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      unitConfig.ConditionPathExists = cfg.diskPath;
      path = with pkgs; [coreutils iproute2 jq socat];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = 90;
        UMask = "0077";
      };

      script = ''
        ${cleanup}

        vars_path=${escapeShellArg cfg.efiVarsPath}
        vars_template=${escapeShellArg ovmf.variables}
        if [[ ! -e "$vars_path" ]]; then
          vars_tmp=$(mktemp -- "$vars_path.XXXXXX")
          trap 'rm -f -- "$vars_tmp"' EXIT
          cp -- "$vars_template" "$vars_tmp"
          ln -T -- "$vars_tmp" "$vars_path"
          rm -- "$vars_tmp"
          trap - EXIT
        fi
        # A Proxmox EFI disk can include padding after the variable store.
        vars_size=$(stat -Lc %s -- "$vars_template")

        parent=${escapeShellArg cfg.parentInterface}
        mac=${escapeShellArg cfg.macAddress}
        shim_ip=${escapeShellArg cfg.hostShimIp}
        ip link add link "$parent" name ha-host0 type macvlan mode bridge
        ip addr add "$shim_ip/32" dev ha-host0
        ip link set ha-host0 up
        # The route also gives reverse-path filtering the correct ingress interface.
        ip route replace ${guestRoute} dev ha-host0 src "$shim_ip"

        ip link add link "$parent" name ha-tap0 address "$mac" type macvtap mode bridge
        ip link set ha-tap0 up
        read -r ifindex < /sys/class/net/ha-tap0/ifindex
        tap="/dev/tap$ifindex"
        for ((attempt = 0; attempt < 50; attempt++)); do
          [[ -c "$tap" ]] && break
          sleep 0.1
        done
        if [[ ! -c "$tap" ]]; then
          echo "macvtap device $tap did not appear" >&2
          exit 1
        fi

        exec 3<>"$tap"
        exec ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 \
          -name homelab-homeassistant \
          -machine q35,accel=kvm \
          -cpu host \
          -smp ${toString cfg.vcpus} \
          -m ${toString cfg.memoryMb} \
          -drive ${escapeShellArg "if=pflash,unit=0,format=raw,readonly=on,file=${ovmf.firmware}"} \
          -drive ${escapeShellArg "if=pflash,unit=1,format=raw,file=${qemuPath cfg.efiVarsPath}"}",size=$vars_size" \
          -device virtio-scsi-pci,id=scsi0 \
          -drive ${escapeShellArg "if=none,id=disk0,file=${qemuPath cfg.diskPath},format=${cfg.diskFormat},cache=writeback,aio=threads,discard=unmap"} \
          -device scsi-hd,bus=scsi0.0,drive=disk0,bootindex=1 \
          -netdev tap,id=net0,fd=3 \
          -device "virtio-net-pci,netdev=net0,mac=$mac" \
          -device qemu-xhci,id=xhci \
          ${escapeShellArgs usbArgs} -qmp unix:${qmpSocket},server=on,wait=off \
          -display none -serial none -monitor none
      '';

      preStop = ''
        set -o pipefail
        if [[ -n "''${MAINPID:-}" ]] &&
          printf '%s\n' '{"execute":"qmp_capabilities"}' '{"execute":"system_powerdown","id":"powerdown"}' |
            timeout 5s socat -t 2 - UNIX-CONNECT:${qmpSocket} |
            jq -es 'any(.[]; .id == "powerdown" and has("return"))' >/dev/null; then
          timeout 80s tail --pid="$MAINPID" -f /dev/null || true
        fi
      '';

      postStop = cleanup;
    };
  };
}
