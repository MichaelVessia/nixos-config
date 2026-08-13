{
  config,
  pkgs,
  ...
}: {
  # On darwin, Zed is installed via Homebrew cask (see hosts/flomac).
  home.packages = pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.zed-editor];

  home.file.".config/zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/modules/programs/zed/settings.json";

  home.file.".config/zed/keymap.json".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/modules/programs/zed/keymap.json";
}
