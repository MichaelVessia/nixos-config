{config, ...}: {
  home.file.".config/zed/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/modules/programs/zed/settings.json";

  home.file.".config/zed/keymap.json".source =
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/nixos-config/modules/programs/zed/keymap.json";
}
