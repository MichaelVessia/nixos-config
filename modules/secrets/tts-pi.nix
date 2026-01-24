{config, ...}: {
  sops = {
    defaultSopsFile = ../../secrets/tts-pi.yaml;

    # For headless systems, derive age key from SSH host key
    # This gets created automatically on first boot
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    # Example secrets - uncomment and add your own
    # secrets.wifi_password = {};
    # secrets.api_token = {};
  };

  # ──────────────────────────────────────────────────────────────────────────────
  # Use secrets in systemd services (common for headless servers)
  # ──────────────────────────────────────────────────────────────────────────────
  # systemd.services.my-service = {
  #   serviceConfig = {
  #     EnvironmentFile = config.sops.secrets.api_token.path;
  #     ExecStart = "...";
  #   };
  # };
}
