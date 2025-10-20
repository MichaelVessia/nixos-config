{
  config,
  pkgs,
  lib,
  ...
}: {
  home.file.".claude/CLAUDE.md".source = ./global-memory.md;
}
