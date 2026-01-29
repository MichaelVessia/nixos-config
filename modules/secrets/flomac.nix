{config, ...}: {
  sops = {
    defaultSopsFile = ../../secrets/flomac.yaml;

    # Age key location on macOS
    age.keyFile = "/Users/michael.vessia/.config/sops/age/keys.txt";

    secrets.flocasts_npm_token = {};
    secrets.github_token = {};
    secrets.jira_api_token = {};
    secrets.dd_app_key = {};
    secrets.dd_api_key = {};
  };
}
