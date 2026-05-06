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

  # Skill names enumerated from the same sources agent-skills-nix consumes,
  # so we can declare one home.file entry per skill instead of owning the
  # whole skills directory. That leaves siblings written by `flo skills add`
  # (and similar tools) untouched on home-manager activation.
  dirNames = path:
    lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
  personalNames = dirNames ./shared/skills;
  superpowersNames = lib.remove "using-superpowers" (dirNames "${inputs.superpowers}/skills");
  skillNames = lib.unique (personalNames ++ superpowersNames);

  perSkillSymlinks = prefix:
    lib.listToAttrs (map (name: {
        name = "${prefix}/${name}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills/${name}";
      })
      skillNames);
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

    home.file =
      perSkillSymlinks ".claude/skills"
      // perSkillSymlinks ".codex/skills"
      // perSkillSymlinks ".config/opencode/skills";
  };
}
