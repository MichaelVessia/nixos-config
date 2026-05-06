{
  pkgs,
  floai,
  ...
}: let
  floCli = floai.packages.${pkgs.system}.default.overrideAttrs (oldAttrs: {
    postBunSetInstallCacheDirPhase =
      (oldAttrs.postBunSetInstallCacheDirPhase or "")
      + ''
        # Bun renames package cache entries during install, so the copied
        # bun2nix cache must be writable after it leaves the Nix store.
        chmod -R u+w "$BUN_INSTALL_CACHE_DIR"
      '';
  });
in {
  home.packages = [floCli];
}
