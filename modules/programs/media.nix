{pkgs, ...}: {
  home.packages = with pkgs; [
    pinta
    spotify
    yt-dlp
  ];
}
