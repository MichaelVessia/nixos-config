# X to Obsidian - background server for Chrome extension
#
# Commands:
#   systemctl --user status x-to-obsidian   # check status
#   systemctl --user restart x-to-obsidian  # restart
#   systemctl --user stop x-to-obsidian     # stop
#   journalctl --user -u x-to-obsidian -f   # tail logs
{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isLinux {
  systemd.user.services.x-to-obsidian = {
    Unit = {
      Description = "X to Obsidian Server";
      After = ["network.target"];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/michaelvessia/Projects/x-to-obsidian";
      ExecStart = "${pkgs.bun}/bin/bun run dev";
      Restart = "on-failure";
      EnvironmentFile = "/home/michaelvessia/Projects/x-to-obsidian/.env";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
