{
  lib,
  config,
  pkgs,
  ...
}: {
  # Brave browser - macOS uses Homebrew
  programs.brave = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    extensions = [
      {id = "cnjifjpddelmedmihgijeibhnjfabmlf";} # Obsidian Web Clipper
      {id = "nngceckbapebfimnlniiiahkandclblb";} # Bitwarden
      {id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";} # Dark Reader
      {id = "imfcckkmcklambpijbgcebggegggkgla";} # Monarch Money
      {id = "mnjggcdmjocbbbhaepdhchncahnbgone";} # SponsorBlock
      {id = "khncfooichmfjbepaaaebmommgaepoid";} # Unhook
    ];
  };
}
