{
  config,
  lib,
  inputs,
  ...
}: let
  superpowersFiltered = lib.cleanSourceWith {
    src = inputs.superpowers;
    filter = path: type: let
      root = toString inputs.superpowers;
      fullPath = toString path;
      relPath = lib.removePrefix "${root}/" fullPath;
    in
      !(lib.hasPrefix "skills/using-superpowers" relPath);
  };
in {
  imports = [inputs.agent-skills-nix.homeManagerModules.default];

  config = {
    programs.agent-skills = {
      enable = true;
      sources = {
        personal.path = ./shared/skills;
        superpowers = {
          path = superpowersFiltered;
          subdir = "skills";
        };
      };
      skills.enableAll = true;
      targets = {
        claude = {
          dest = "$HOME/.agents/skills";
          structure = "symlink-tree";
        };
        codex = {
          enable = true;
          dest = "$HOME/.agents/skills";
          structure = "symlink-tree";
        };
        opencode = {
          enable = true;
          dest = "$HOME/.agents/skills";
          structure = "symlink-tree";
        };
      };
    };

    home.file = {
      ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
      ".codex/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
      ".config/opencode/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
    };
  };
}
