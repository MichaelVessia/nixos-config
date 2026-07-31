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

  # Homebrew's tap-trust checks break `brew bundle --cleanup` during darwin
  # activation for third-party taps (humanlayer, nkzw-tech): `brew trust` state
  # does not survive brew bundle runs, so activation dies before home-manager
  # ever runs. Opt out of trust checks; our taps are declared in hosts/flomac.
  # brew's launcher sources this file itself, so it applies even under the
  # activation script's stripped environment.
  home.file.".homebrew/brew.env".text = ''
    HOMEBREW_NO_REQUIRE_TAP_TRUST=1
  '';

  # Moshi's phone-generated SSH public key. The bootstrap pairing command
  # creates a regular authorized_keys file, so replace it on first activation.
  home.file.".ssh/authorized_keys" = {
    force = true;
    text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHN3Hc3Ls44cFgAZE6f5By/ER+wkPpNMnCowP+CPMneS moshi-pair:host_3e50c88ec5f3440f8bf588b7d70dd74c:EfXCl1Mb:2026-07-31T19:55:55Z
    '';
  };

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
