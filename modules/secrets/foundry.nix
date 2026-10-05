{...}: {
  sops = {
    defaultSopsFile = ../../secrets/foundry.yaml;

    # Age key location (generated once, stored outside nix store)
    age.keyFile = "/home/michaelvessia/.config/sops/age/keys.txt";

    # Declare secrets here (must match keys in secrets/foundry.yaml)
    secrets.flocasts_npm_token = {};
  };
}
