{ config, pkgs, ... }:

{
  programs.brave = {
    enable = true;
    extensions = [
      { id = "cnjifjpddelmedmihgijeibhnjfabmlf"; } # Obsidian Web Clipper
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
      { id = "imfcckkmcklambpijbgcebggegggkgla"; } # Monarch Money
      { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # SponsorBlock
      { id = "khncfooichmfjbepaaaebmommgaepoid"; } # Unhook
    ];
  };
}
