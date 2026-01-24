{config, ...}: {
  sops = {
    defaultSopsFile = ../../secrets/framework13.yaml;

    # Age key location (generated once, stored outside nix store)
    age.keyFile = "/home/michaelvessia/.config/sops/age/keys.txt";

    # Declare secrets here (must match keys in secrets/framework13.yaml)
    secrets.test_secret = {};

    # More examples - uncomment and add your own
    # secrets.example_api_key = {};
    # secrets.example_password = {
    #   owner = "michaelvessia";
    #   mode = "0400";
    # };
    # secrets.example_ssh_key = {
    #   path = "/home/michaelvessia/.ssh/deploy_key";
    #   owner = "michaelvessia";
    #   mode = "0600";
    # };

    # Template example: combine multiple secrets into an env file
    # templates."example-env".content = ''
    #   API_KEY=${config.sops.placeholder.example_api_key}
    #   PASSWORD=${config.sops.placeholder.example_password}
    # '';
  };

  # ──────────────────────────────────────────────────────────────────────────────
  # Option 1: Export secrets as env vars in shell
  # ──────────────────────────────────────────────────────────────────────────────
  # programs.zsh.interactiveShellInit = ''
  #   export EXAMPLE_API_KEY="$(cat ${config.sops.secrets.example_api_key.path} 2>/dev/null)"
  # '';

  # ──────────────────────────────────────────────────────────────────────────────
  # Option 2: Use secrets in systemd services
  # ──────────────────────────────────────────────────────────────────────────────
  # systemd.services.example-service = {
  #   description = "Example service using secrets";
  #   serviceConfig = {
  #     # Single secret as env file (file contains just the value)
  #     # Use with: Environment=API_KEY_FILE=%d/api_key
  #     LoadCredential = "api_key:${config.sops.secrets.example_api_key.path}";
  #
  #     # Or use a template with multiple env vars
  #     EnvironmentFile = config.sops.templates."example-env".path;
  #
  #     ExecStart = "${pkgs.example}/bin/example";
  #   };
  # };
}
