{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  osConfig,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs
    ../../modules/programs/agents/options.nix
    ../../modules/programs/agents/shared.nix
    ../../modules/programs/agents/codex.nix
    ../../modules/programs/agents/grok.nix
    ../../modules/programs/agents/plannotator.nix
    ../../modules/programs/niri.nix
    ../../modules/programs/hex
  ];

  home.packages = [
    inputs.grok-bot.packages.${pkgs.system}.default
    (pkgs.callPackage ../../modules/programs/t3code-nightly/package.nix {
      providerPackages = [
        config.agentHarnesses.codex.package
        inputs.llm-agents.packages.${pkgs.system}.grok
        pkgs.nodejs
      ];
    })
  ];

  agentHarnesses.executor.enable = true;
  agentHarnesses.cliproxyHub.enable = false;
  agentHarnesses.pstack.modelsFile = ../../modules/programs/agents/shared/pstack-models-personal.md;

  # Preserve existing shares until this device can be inventoried.
  services.syncthing.overrideDevices = false;
  services.syncthing.overrideFolders = false;

  vaults = {
    deviceName = osConfig.networking.hostName;
    profile = "personal";
  };

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";
}
