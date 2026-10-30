{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
    ../../modules/secrets/flomac.nix
  ];

  vaults = {
    deviceName = "flomac";
    profile = "work";
  };

  home.username = "michael.vessia";
  home.homeDirectory = "/Users/michael.vessia";

  programs.ssh.includes = ["~/.namespace/ssh/*.ssh"];

  # Hex rejects symlinks that point outside its configuration directory.
  home.activation.hexConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${pkgs.coreutils}/bin/install -D -m 0644 \
      ${../../modules/programs/hex/hex.config.ts} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.config/hex/hex.config.ts"}
    run ${pkgs.coreutils}/bin/install -D -m 0644 \
      ${../../modules/programs/hex/transformations.ts} \
      ${lib.escapeShellArg "${config.home.homeDirectory}/.config/hex/transformations.ts"}

    # Use Hex's live API; never overwrite settings.json while Hex runs.
    if [ -x /Applications/Hex.app/Contents/MacOS/hex ] && \
      /Applications/Hex.app/Contents/MacOS/hex status --json >/dev/null 2>&1; then
      run /Applications/Hex.app/Contents/MacOS/hex settings set \
        dictation_processing.default_mode \
        "$(${pkgs.coreutils}/bin/cat ${../../modules/programs/hex/default-mode.json})"
      run /Applications/Hex.app/Contents/MacOS/hex settings set \
        dictation_processing.modes \
        "$(${pkgs.coreutils}/bin/cat ${../../modules/programs/hex/modes.json})"
    fi
  '';

  # Homebrew's tap-trust checks break `brew bundle --cleanup` during darwin
  # activation for third-party taps (humanlayer, nkzw-tech): `brew trust` state
  # does not survive brew bundle runs, so activation dies before home-manager
  # ever runs. Opt out of trust checks; our taps are declared in hosts/flomac.
  # brew's launcher sources this file itself, so it applies even under the
  # activation script's stripped environment.
  home.file.".homebrew/brew.env".text = ''
    HOMEBREW_NO_REQUIRE_TAP_TRUST=1
  '';

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
