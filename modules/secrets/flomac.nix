{
  config,
  lib,
  ...
}: {
  sops = {
    defaultSopsFile = ../../secrets/flomac.yaml;

    # Age key location on macOS
    age.keyFile = "/Users/michael.vessia/.config/sops/age/keys.txt";

    # Fix: launchd agent needs PATH for getconf and newfs_hfs (override empty default)
    environment.PATH = lib.mkForce "/usr/bin:/bin:/usr/sbin:/sbin";

    secrets.flocasts_npm_token = {};
    secrets.github_token = {};
    secrets.jira_api_token = {};
    secrets.dd_app_key = {};
    secrets.dd_api_key = {};
    secrets.dd_telemetry_api_key = {};
  };
}
