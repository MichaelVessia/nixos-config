{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  frameCfg = cfg.frame;
in {
  options.homelab.frame = {
    enable = lib.mkEnableOption "garage-frame host preparation";
  };

  config = lib.mkIf (cfg.enable && frameCfg.enable) {
    systemd.tmpfiles.rules = [
      "d /opt/garage-frame 0755 root root -"
    ];

    sops.secrets.homelab_frame_env = {
      sopsFile = cfg.backups.sopsFile;
      owner = "root";
      mode = "0400";
    };

    # Install a real file (not a symlink into /run/secrets.d) so Docker bind-mounts work cleanly.
    system.activationScripts.homelabFrameEnvFile = {
      deps = ["setupSecrets"];
      text = ''
        ${pkgs.coreutils}/bin/install -d -m 0755 -o root -g root /opt/garage-frame
        (
          tmp=$(${pkgs.coreutils}/bin/mktemp /opt/garage-frame/.frame.env.XXXXXX) || exit 1
          trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
          ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg config.sops.secrets.homelab_frame_env.path} > "$tmp" &&
            ${pkgs.coreutils}/bin/chown root:65532 "$tmp" &&
            ${pkgs.coreutils}/bin/chmod 0440 "$tmp" &&
            ${pkgs.coreutils}/bin/mv -fT "$tmp" /opt/garage-frame/frame.env
        )
      '';
    };

    networking.firewall.allowedTCPPorts = [
      cfg.topology.services.frame.port
    ];

    homelab.backups.paths = [
      "/opt/garage-frame"
    ];
  };
}
