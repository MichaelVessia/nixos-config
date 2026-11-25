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
        # Fail stalled sessions after about 90 seconds instead of hanging.
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
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
        user = "michaelvessia";
        extraOptions = lib.optionalAttrs pkgs.stdenv.isDarwin {
          HostKeyAlias = "192.168.1.18";
        };
      };
      "flomac" = {
        hostname = "c6dwvf3hjg.bison-gray.ts.net";
        user = "michael.vessia";
      };
      "forge" = {
        hostname = "forge";
        user = "michaelvessia";
      };
      "hearth" = {
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

  # The Nix store owner is unmapped in T3 user namespaces.
  home.file.".ssh/config".enable = false;
  home.activation.installSshConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if [[ ! -v DRY_RUN ]]; then
      (
        sshDir="$HOME/.ssh"
        mkdir -p "$sshDir"
        chmod 0700 "$sshDir"

        tmp="$(mktemp "$sshDir/.config.XXXXXX")"
        trap 'rm -f "$tmp"' EXIT
        cat ${config.home.file.".ssh/config".source} > "$tmp"
        chmod 0600 "$tmp"
        mv -fT "$tmp" "$sshDir/config"
      )
    fi
  '';

  # Enable SSH agent service (Linux only)
  services.ssh-agent.enable = lib.mkDefault pkgs.stdenv.isLinux;
}
