# beads_viewer (bv) - TUI for the Beads issue tracker
# https://github.com/Dicklesworthstone/beads_viewer
{
  lib,
  pkgs,
  ...
}: let
  beads-viewer = pkgs.buildGoModule rec {
    pname = "beads-viewer";
    version = "0.11.2";

    src = pkgs.fetchFromGitHub {
      owner = "Dicklesworthstone";
      repo = "beads_viewer";
      rev = "v${version}";
      hash = "sha256-EpQyLQR6BdPm5w98xVXUwKG0vXFNkx4P9p8/pmoQyMg=";
    };

    vendorHash = "sha256-rtIqTK6ez27kvPMbNjYSJKFLRbfUv88jq8bCfMkYjfs=";

    # Tests require $HOME which doesn't exist in nix sandbox
    doCheck = false;

    meta = with lib; {
      description = "Elegant keyboard-driven terminal interface for the Beads issue tracker";
      homepage = "https://github.com/Dicklesworthstone/beads_viewer";
      license = licenses.mit;
      mainProgram = "bv";
    };
  };
in {
  home.packages = [beads-viewer];
}
