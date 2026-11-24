{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab;
  runnerCfg = cfg.githubRunner;
in {
  options.homelab.githubRunner = {
    enable = lib.mkEnableOption "self-hosted GitHub Actions runner for homelab-apps";

    url = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/MichaelVessia/homelab-apps";
      description = "GitHub repository URL to register the runner against.";
    };

    name = lib.mkOption {
      type = lib.types.str;
      default = "hearth";
      description = "Runner name and custom label registered in GitHub Actions.";
    };
  };

  config = lib.mkIf (cfg.enable && runnerCfg.enable) {
    sops.secrets.homelab_github_runner_token = {
      sopsFile = cfg.backups.sopsFile;
      owner = "root";
      mode = "0400";
    };

    services.github-runners.homelab-apps = {
      enable = true;
      url = runnerCfg.url;
      name = runnerCfg.name;
      replace = true;
      extraLabels = [runnerCfg.name];
      tokenFile = config.sops.secrets.homelab_github_runner_token.path;
      extraPackages = with pkgs; [
        bun
        curl
        docker
        jq
        nodejs
      ];
      serviceOverrides = {
        # Disable user namespace remapping so SupplementaryGroups = ["docker"] can access /run/docker.sock.
        PrivateUsers = false;
        SupplementaryGroups = ["docker"];
        ReadWritePaths = ["/run/docker.sock"];
        # Standard 0022 umask so Docker image COPY steps keep built assets readable by non-root container users.
        UMask = "0022";
      };
    };

    systemd.services.github-runner-homelab-apps.after = ["docker.service"];
  };
}
