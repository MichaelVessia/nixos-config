{
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [
      (pkgs.writeShellScriptBin "kuma-cli" ''
        exec ${pkgs.autokuma}/bin/kuma \
          --url "$KUMA_URL" \
          --username "$KUMA_USERNAME" \
          --password "$KUMA_PASSWORD" \
          "$@"
      '')
    ];
  };
}
