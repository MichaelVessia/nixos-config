{
  lib,
  config,
  pkgs,
  ...
}: {
  # SSH configuration
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Host-specific configurations
    matchBlocks = {
      "*" = {
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
      "proxmox" = {
        hostname = "192.168.1.200";
        user = "root";
      };
      "nas" = {
        hostname = "192.168.1.176";
        user = "michaelvessia";
        port = 8222;
      };
      "homeassistant" = {
        hostname = "192.168.1.227";
        user = "hassio";
      };
      "udm" = {
        hostname = "192.168.1.1";
        user = "root";
      };
      "claude-casino" = {
        hostname = "100.86.122.24";
        user = "cc";
        setEnv = {
          TERM = "xterm-256color";
        };
      };
    };
  };

  # Enable SSH agent service (Linux only)
  services.ssh-agent.enable = lib.mkDefault pkgs.stdenv.isLinux;
}
