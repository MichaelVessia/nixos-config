{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
    ../../modules/secrets/flomac.nix
  ];

  home.username = "michael.vessia";
  home.homeDirectory = "/Users/michael.vessia";

  # Export sops-nix secrets to launchd environment (available to all GUI apps and shells)
  launchd.agents.sops-nix-env = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          /bin/wait4path /nix/store
          # Wait for actual secret file, not just directory (which may exist empty)
          /bin/wait4path "$HOME/.config/sops-nix/secrets/flocasts_npm_token"
          for secret in "$HOME/.config/sops-nix/secrets"/*; do
            name=$(basename "$secret" | tr '[:lower:]' '[:upper:]')
            value=$(cat "$secret")
            /bin/launchctl setenv "$name" "$value"
          done
        ''
      ];
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/sops-nix-env/stdout";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/sops-nix-env/stderr";
    };
  };
}
