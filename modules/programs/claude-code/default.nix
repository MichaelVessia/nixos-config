{
  config,
  pkgs,
  lib,
  ...
}: {
  home.file.".claude/CLAUDE.md".source = ./global-memory.md;

  home.file.".claude/commands" = {
    source = ./commands;
    recursive = true;
  };

  home.file.".claude/claude-statusline" = {
    source = ./claude-statusline.sh;
    executable = true;
  };

  home.file.".claude/settings.json".source = ./settings.json;
}
