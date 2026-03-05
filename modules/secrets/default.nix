{config, ...}: {
  sops = {
    defaultSopsFile = ../../secrets/framework13.yaml;

    # Age key location (generated once, stored outside nix store)
    age.keyFile = "/home/michaelvessia/.config/sops/age/keys.txt";

    # Declare secrets here (must match keys in secrets/framework13.yaml)
    secrets.paperless_url.owner = "michaelvessia";
    secrets.paperless_token.owner = "michaelvessia";
    secrets.x_to_obsidian_vault_path.owner = "michaelvessia";
    secrets.x_to_obsidian_llm_provider.owner = "michaelvessia";
    secrets.x_to_obsidian_google_api_key.owner = "michaelvessia";
    secrets.fmcal_username.owner = "michaelvessia";
    secrets.fmcal_password.owner = "michaelvessia";
    secrets.hass_server.owner = "michaelvessia";
    secrets.hass_token.owner = "michaelvessia";
    secrets.freshrss_api_user.owner = "michaelvessia";
    secrets.freshrss_api_password.owner = "michaelvessia";
    secrets.freshrss_url.owner = "michaelvessia";
    secrets.kuma_url.owner = "michaelvessia";
    secrets.kuma_username.owner = "michaelvessia";
    secrets.kuma_password.owner = "michaelvessia";
  };

  # ──────────────────────────────────────────────────────────────────────────────
  # Export secrets as env vars in shell
  # ──────────────────────────────────────────────────────────────────────────────
  # Note: Shell exports are in modules/programs/shell.nix (home-manager manages zsh)
  # Example for NixOS-managed zsh:
  # programs.zsh.interactiveShellInit = ''
  #   export MY_SECRET="$(cat ${config.sops.secrets.my_secret.path} 2>/dev/null)"
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
