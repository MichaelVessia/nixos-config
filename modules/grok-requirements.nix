# Grok replaces ~/.grok/requirements.toml with a copy synced from xAI, so the
# model allowlist lives in the root-owned system file. The CLIProxyAPI hub
# also lists the Claude and Codex subscriptions, and Grok must not use them.
{pkgs, ...}: {
  environment.etc."grok/requirements.toml".source = (pkgs.formats.toml {}).generate "grok-requirements.toml" {
    models.allowed_models = ["grok-*"];
  };
}
