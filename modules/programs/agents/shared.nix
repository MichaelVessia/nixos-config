{
  config,
  lib,
  inputs,
  ...
}: let
  # Enumerate personal skills from the source dir so we can declare one
  # home.file entry per skill instead of owning the whole skills directory.
  # That leaves siblings written by `flo skills add` (and similar tools)
  # untouched on home-manager activation.
  dirNames = path:
    lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
  gwsSkillsPath = inputs.googleworkspace-cli + "/skills";
  skillNames = dirNames ./shared/skills ++ dirNames gwsSkillsPath;

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
        googleworkspace.path = gwsSkillsPath;
      };
      skills.enableAll = true;
      # Single bundle dest under ~/.agents/skills; per-tool paths layered on
      # top via perSkillSymlinks below. `structure = "link"` declares one
      # home.file entry per skill (recursive symlinks) so siblings written by
      # `flo skills add` (and similar tools) survive home-manager activation.
      # `symlink-tree` would run an activation sync script that owns the whole
      # directory and deletes anything it didn't put there.
      targets = {
        agents = {
          enable = true;
          dest = ".agents/skills";
          structure = "link";
        };
      };
    };

    home.file =
      perSkillSymlinks ".claude/skills"
      // perSkillSymlinks ".codex/skills"
      // perSkillSymlinks ".config/opencode/skills";
  };
}
