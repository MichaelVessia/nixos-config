{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # home-manager, used for managing user configuration
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # nix-darwin for macOS system management
    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    nvf = {
      url = "github:NotAShelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    ghostty.url = "github:ghostty-org/ghostty";
    niri.url = "github:sodiboo/niri-flake";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    x-to-obsidian.url = "github:MichaelVessia/x-to-obsidian";
    fmcal.url = "github:MichaelVessia/fmcal";
    paperless-cli.url = "github:MichaelVessia/paperless-cli";
    subq.url = "github:MichaelVessia/subq";
    bun2nix.url = "github:nix-community/bun2nix";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    darwin,
    claude-code,
    nvf,
    nixos-hardware,
    ghostty,
    niri,
    noctalia,
    sops-nix,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};

    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.mkShell {
        packages = with nixpkgs.legacyPackages.${system}; [
          alejandra
          lefthook
          sops
          age
          ssh-to-age
        ];
        shellHook = ''
          lefthook install --force
        '';
      };
    });

    nixosConfigurations = {
      framework13 = let
        username = "michaelvessia";
        specialArgs = {
          inherit username;
          inherit inputs;
          inherit pkgs-unstable;
        };
      in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          system = "x86_64-linux";

          modules = [
            ./hosts/framework13/default.nix
            ./modules/secrets

            nixos-hardware.nixosModules.framework-12th-gen-intel
            sops-nix.nixosModules.sops

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [
                niri.homeModules.niri
                noctalia.homeModules.default
              ];

              home-manager.extraSpecialArgs = inputs // specialArgs;
              home-manager.users.${username} = import ./users/${username}/home.nix;

              # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            }
          ];
        };

      tts-pi = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          nixos-hardware.nixosModules.raspberry-pi-3
          sops-nix.nixosModules.sops
          ./hosts/tts-pi/default.nix
          ./modules/secrets/tts-pi.nix
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ];
      };
    };

    # SD card image for tts-pi
    images.tts-pi = self.nixosConfigurations.tts-pi.config.system.build.sdImage;

    darwinConfigurations = {
      flomac = let
        username = "michael.vessia";
        system = "aarch64-darwin";
        specialArgs = {
          inherit username;
          inherit inputs;
          pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
        };
      in
        darwin.lib.darwinSystem {
          inherit system;
          inherit specialArgs;

          modules = [
            ./hosts/flomac/default.nix

            # make home-manager as a module of nix-darwin
            # so that home-manager configuration will be deployed automatically when executing `darwin-rebuild switch`
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.sharedModules = [
                sops-nix.homeManagerModules.sops
              ];

              home-manager.extraSpecialArgs = inputs // specialArgs;
              home-manager.users.${username} = import ./users/${username}/home.nix;
            }
          ];
        };
    };
  };
}
