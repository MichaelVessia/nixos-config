{
  description = "flomac nix-darwin configuration with private floai input";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    ghostty.url = "github:ghostty-org/ghostty";
    niri.url = "github:sodiboo/niri-flake";
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    x-to-obsidian.url = "github:MichaelVessia/x-to-obsidian";
    fmcal.url = "github:MichaelVessia/fmcal";
    floai.url = "git+ssh://git@github.com/flocasts/floai.git?ref=master";
    paperless-cli.url = "github:MichaelVessia/paperless-cli";
    subq.url = "github:MichaelVessia/subq";

    wiggle-puppy = {
      url = "github:jordangarrison/wiggle-puppy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bun2nix.url = "github:nix-community/bun2nix";

    worktrunk = {
      url = "github:max-sixty/worktrunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills-nix = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    googleworkspace-cli = {
      url = "github:googleworkspace/cli";
      flake = false;
    };
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    darwin,
    sops-nix,
    ...
  }: let
    username = "michael.vessia";
    system = "aarch64-darwin";
    specialArgs = {
      inherit username inputs;
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    };
  in {
    darwinConfigurations.flomac = darwin.lib.darwinSystem {
      inherit system specialArgs;

      modules = [
        ./default.nix

        # make home-manager as a module of nix-darwin
        # so that home-manager configuration will be deployed automatically when executing `darwin-rebuild switch`
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.sharedModules = [
            sops-nix.homeManagerModules.sops
            inputs.worktrunk.homeModules.default
          ];

          home-manager.extraSpecialArgs = inputs // specialArgs;
          home-manager.users.${username} = import ../../users/${username}/home.nix;
        }
      ];
    };
  };
}
