{config, ...}: {
  sops = {
    defaultSopsFile = ../../secrets/flomac.yaml;

    # Age key location on macOS
    age.keyFile = "/Users/michael.vessia/.config/sops/age/keys.txt";

    # Example secrets - uncomment and add your own
    # secrets.example_api_key = {};
    # secrets.example_password = {
    #   mode = "0400";
    # };
  };

  # ──────────────────────────────────────────────────────────────────────────────
  # Export secrets as env vars in shell (home-manager)
  # Secrets are at: ~/.config/sops-nix/secrets/<name>
  # ──────────────────────────────────────────────────────────────────────────────
  # programs.zsh.initExtra = ''
  #   export EXAMPLE_API_KEY="$(cat ${config.sops.secrets.example_api_key.path} 2>/dev/null)"
  # '';
}
