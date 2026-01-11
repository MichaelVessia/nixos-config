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

  home.file.".claude/skills" = {
    source = ./skills;
    recursive = true;
  };

  home.file.".claude/agents" = {
    source = ./agents;
    recursive = true;
  };

  home.file.".claude/claude-statusline" = {
    source = ./claude-statusline.sh;
    executable = true;
  };

  home.file.".claude/claude-notify" = {
    source = ./claude-notify.sh;
    executable = true;
  };

  home.file.".claude/claude-alert" = {
    source = ./claude-alert.sh;
    executable = true;
  };

  home.file.".claude/claude-sleep-inhibit" = {
    source = ./claude-sleep-inhibit.sh;
    executable = true;
  };

  home.file.".claude/git-safety-guard" = {
    source = ./git-safety-guard.py;
    executable = true;
  };

  home.file.".claude/settings.json".source = ./settings.json;
}
