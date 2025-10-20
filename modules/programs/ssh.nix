{
  config,
  pkgs,
  ...
}: {
  # SSH configuration
  programs.ssh = {
    enable = true;

    # SSH configuration options
    extraConfig = ''
      AddKeysToAgent yes
    '';

    # Host-specific configurations
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  # Enable SSH agent service
  services.ssh-agent.enable = true;
}
