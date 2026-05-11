{
  pkgs,
  floai,
  ...
}: let
  floCli = floai.packages.${pkgs.system}.default.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [pkgs.git];
    postBunSetInstallCacheDirPhase =
      (oldAttrs.postBunSetInstallCacheDirPhase or "")
      + ''
        # Bun renames package cache entries during install, so the copied
        # bun2nix cache must be writable after it leaves the Nix store.
        chmod -R u+w "$BUN_INSTALL_CACHE_DIR"
        # floai's `prepare` script invokes `lefthook install`, which needs
        # a git repo. The Nix sandbox doesn't have one, so create it here.
        git init -q
      '';
  });
in {
  home.packages = [floCli];
}
