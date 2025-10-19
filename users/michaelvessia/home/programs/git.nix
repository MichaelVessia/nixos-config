{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Michael Vessia";
    userEmail = "michael@vessia.net";
  };
}
