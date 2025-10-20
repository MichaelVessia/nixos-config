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
}
