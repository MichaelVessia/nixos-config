{
  # Trust the homelab Caddy CA for internal HTTPS services such as Executor.
  security.pki.certificateFiles = [./caddy-local-root.crt];
  # Bun and Node do not consistently use the NixOS system trust bundle by default.
  environment.sessionVariables = {
    SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-bundle.crt";
  };
}
