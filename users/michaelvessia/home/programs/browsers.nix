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

  # Set Brave as default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "brave-browser.desktop";
      "x-scheme-handler/http" = "brave-browser.desktop";
      "x-scheme-handler/https" = "brave-browser.desktop";
      "x-scheme-handler/about" = "brave-browser.desktop";
      "x-scheme-handler/unknown" = "brave-browser.desktop";
    };
  };
}
