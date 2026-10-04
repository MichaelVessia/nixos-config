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
      "foundry" = {
        hostname =
          if pkgs.stdenv.isDarwin
          then "foundry.bison-gray.ts.net"
          else "foundry";
        user = "foundry";
        extraOptions = lib.optionalAttrs pkgs.stdenv.isDarwin {
          HostKeyAlias = "192.168.1.18";
        };
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
    };
  };

  # Enable SSH agent service (Linux only)
  services.ssh-agent.enable = lib.mkDefault pkgs.stdenv.isLinux;
}
