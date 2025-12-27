# basalt - TUI for managing Obsidian notes from the terminal
# https://github.com/erikjuhani/basalt
{
  lib,
  pkgs,
  ...
}: let
  basalt = pkgs.rustPlatform.buildRustPackage rec {
    pname = "basalt";
    version = "0.11.2";

    src = pkgs.fetchFromGitHub {
      owner = "erikjuhani";
      repo = "basalt";
      rev = "basalt/v${version}";
      hash = "sha256-+DLobCoBTZxgwUaD2MofhRr5Y57bUbujg7N/Lcg8GZA=";
    };

    cargoHash = "sha256-C+ZFwxp35cEFUKhJn8CpZxrAnNVb9bxV71m4OVAIYzI=";

    meta = with lib; {
      description = "TUI Application to manage Obsidian notes directly from the terminal";
      homepage = "https://github.com/erikjuhani/basalt";
      license = licenses.mit;
      mainProgram = "basalt";
    };
  };
in {
  home.packages = [basalt];
}
