{pkgs, ...}: {
  home.packages = with pkgs; [
    spotify
    yt-dlp
  ];
}
