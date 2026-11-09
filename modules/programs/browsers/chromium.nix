{
  lib,
  config,
  pkgs,
  ...
}: {
  # Chromium on Linux; macOS uses Homebrew Brave
  programs.chromium = lib.mkIf pkgs.stdenv.isLinux {
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
