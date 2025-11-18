{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs;
    [
      spotify
      yt-dlp
    ]
    ++ lib.optionals stdenv.isLinux [
      pinta
    ];
}
