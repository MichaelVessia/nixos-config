{
  config,
  lib,
  pkgs,
  ...
}: let
  snapshot = "/var/lib/sentinel-adguard/policy.json";
  receivePolicy = pkgs.writeShellApplication {
    name = "sentinel-receive-adguard-policy";
    runtimeInputs = [pkgs.coreutils pkgs.jq pkgs.systemd pkgs.util-linux];
    text = ''
      umask 077
      exec 9>/var/lib/sentinel-adguard/sync.lock
      flock 9
      incoming=$(mktemp "${snapshot}.incoming.XXXXXX")
      trap 'unlink "$incoming" 2>/dev/null || true' EXIT
      jq --exit-status 'select((.schema_version | type) == "number" and (.dns | type) == "object")' > "$incoming"
      if cmp -s "$incoming" ${snapshot}; then
        exit 0
      fi
      if [ -e ${snapshot} ]; then
        cp ${snapshot} ${snapshot}.previous
      fi
      mv "$incoming" ${snapshot}
      if ! systemctl restart adguardhome.service; then
        if [ -e ${snapshot}.previous ]; then
          mv ${snapshot}.previous ${snapshot}
        else
          unlink ${snapshot}
        fi
        systemctl restart adguardhome.service
        exit 1
      fi
      if [ -e ${snapshot}.previous ]; then
        unlink ${snapshot}.previous
      fi
    '';
  };
  initialPolicy = pkgs.writeText "sentinel-adguard-initial.json" (builtins.toJSON {
    inherit (config.services.adguardhome.package) schema_version;
    dns = {
      upstream_dns = ["https://dns.quad9.net/dns-query"];
      bootstrap_dns = ["9.9.9.9" "149.112.112.112"];
    };
  });
in {
  # The AArch64 NixOS kernel includes the Pi 3B drivers and device tree.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  hardware.deviceTree.name = "broadcom/bcm2837-rpi-3-b.dtb";

  boot.supportedFilesystems = {
    zfs = lib.mkForce false;
    btrfs = lib.mkForce false;
    xfs = lib.mkForce false;
    ntfs = lib.mkForce false;
    cifs = lib.mkForce false;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = ["nofail" "noauto"];
  };

  networking = {
    hostName = "sentinel";
    networkmanager = {
      enable = true;
      dns = "none";
    };
    nameservers = ["9.9.9.9" "149.112.112.112"];
    firewall.interfaces = lib.genAttrs ["enu1u1" "tailscale0"] (_: {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    });
  };

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.pi = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObTdZXSO7j+J+1CKMgpcKvPPhCEZh1c4FT0hNuYTu1r"
    ];
  };
  security.sudo.wheelNeedsPassword = false;
  users.users.root.openssh.authorizedKeys.keys = [
    ''restrict,from="192.168.1.200",command="${lib.getExe receivePolicy}" ${lib.strings.trim (builtins.readFile ./sync-key.pub)}''
  ];
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "forced-commands-only";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "pi"];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  sops = {
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    gnupg.sshKeyPaths = [];
    secrets.adguard_admin_hash.sopsFile = ../../secrets/sentinel.yaml;
  };
  services.adguardhome = {
    enable = true;
    extraArgs = ["--web-addr" "127.0.0.1:3053"];
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/sentinel-adguard 0700 root root -"
    "C ${snapshot} 0600 root root - ${initialPolicy}"
  ];
  systemd.services.adguardhome = {
    serviceConfig.LoadCredential = [
      "admin-hash:${config.sops.secrets.adguard_admin_hash.path}"
      "dns-policy:${snapshot}"
    ];
    preStart = ''
      umask 077
      ${lib.getExe pkgs.jq} --rawfile password "$CREDENTIALS_DIRECTORY/admin-hash" '
        .users = [{name: "admin", password: ($password | rtrimstr("\n"))}]
        | .http.address = "127.0.0.1:3053"
        | .dns.bind_hosts = ["0.0.0.0"]
        | .dns.port = 53
        | .dhcp.enabled = false
      ' "$CREDENTIALS_DIRECTORY/dns-policy" > "$STATE_DIRECTORY/AdGuardHome.yaml.tmp"
      mv "$STATE_DIRECTORY/AdGuardHome.yaml.tmp" "$STATE_DIRECTORY/AdGuardHome.yaml"
    '';
    postStart = ''
      for _ in $(seq 1 30); do
        if [ "$(${lib.getExe pkgs.curl} --silent --max-time 1 --output /dev/null --write-out '%{http_code}' http://127.0.0.1:3053/control/status)" = 401 ]; then
          exit 0
        fi
        sleep 1
      done
      exit 1
    '';
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--advertise-routes=192.168.1.0/24"
      "--accept-routes=false"
      "--accept-dns=false"
    ];
  };

  system.stateVersion = "25.05";
}
