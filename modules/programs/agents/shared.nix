{
  config,
  lib,
  inputs,
  enableHomelabSkills,
  ...
}: let
  # Enumerate personal skills from the source dir so we can declare one
  # home.file entry per skill instead of owning the whole skills directory.
  # That leaves siblings written by `flo skills add` (and similar tools)
  # untouched on home-manager activation.
  dirNames = path:
    lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
  personalSkillNames = dirNames ./shared/skills;
  homelabSkillNames = [
    "freshrss"
    "home-assistant-manager"
    "homelab"
    "homepage-add"
    "paperless"
    "proxmox"
    "uptime-kuma"
  ];
  enabledPersonalSkillNames =
    if enableHomelabSkills
    then personalSkillNames
    else lib.subtractLists homelabSkillNames personalSkillNames;

  # Normalize upstream names that are not valid skill IDs.
  pstackSkillsPath = inputs.pstack + "/pstack/skills";
  pstackNormalized = {
    poteto-mode = "Poteto Mode";
    make-bot-ui = "Make Bot UI";
  };
  pstackExplicitNames = lib.attrNames pstackNormalized;
  pstackSkillNames = lib.subtractLists pstackExplicitNames (dirNames pstackSkillsPath);
  renamePstackSkill = name: {original, ...}: let
    originalName = pstackNormalized.${name};
    renamed = builtins.replaceStrings ["---\nname: ${originalName}\n"] ["---\nname: ${name}\n"] original;
  in
    if renamed == original
    then throw "pstack ${name}/SKILL.md no longer starts with `name: ${originalName}`"
    else renamed;
  teamKitSkillNames = [
    "control-cli"
    "control-ui"
    "deslop"
    "fix-ci"
    "fix-merge-conflicts"
    "get-pr-comments"
    "make-pr-easy-to-review"
    "thermo-nuclear-code-quality-review"
    "what-did-i-get-done"
  ];
  catalogSkillNames = enabledPersonalSkillNames ++ pstackSkillNames ++ teamKitSkillNames;
  skillNames = catalogSkillNames ++ pstackExplicitNames;

  # Point each per-tool symlink at the agent-skills bundle directly.
  # Going through `~/.agents/skills/${name}` via `mkOutOfStoreSymlink` made
  # home-manager's activation collapse the recursive `.agents/skills` target
  # and the per-tool entries onto each other, producing a symlink loop.
  perToolSkillDirs = [
    ".claude/skills"
    ".codex/skills"
    ".config/opencode/skills"
  ];

  perSkillSymlinks = prefix:
    lib.listToAttrs (map (name: {
        name = "${prefix}/${name}";
        value.source = "${config.programs.agent-skills.bundlePath}/${name}";
      })
      skillNames);
in {
  imports = [inputs.agent-skills-nix.homeManagerModules.default];

  config = {
    programs.agent-skills = {
      enable = true;
      sources = {
        personal.path = ./shared/skills;
        pstack = {
          path = pstackSkillsPath;
          filter.nameRegex = lib.concatStringsSep "|" pstackSkillNames;
        };
        cursor-team-kit = {
          path = inputs.pstack + "/cursor-team-kit/skills";
          filter.nameRegex = lib.concatStringsSep "|" teamKitSkillNames;
        };
      };
      skills.enable = catalogSkillNames;
      skills.explicit = lib.listToAttrs (map (name: {
          inherit name;
          value = {
            from = "pstack";
            path = name;
            transform = renamePstackSkill name;
          };
        })
        pstackExplicitNames);
      # Build the bundle for ~/.agents/skills. Replace the module's recursive
      # home.file target with per-skill directory links below so siblings written
      # by `flo skills add` survive home-manager activation.
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

    home.activation.removeLegacyPerToolSkillDirLinks = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
      for dir in ${lib.escapeShellArgs perToolSkillDirs}; do
        path="$HOME/$dir"
        if [ -L "$path" ]; then
          $DRY_RUN_CMD rm "$path"
        fi
      done
    '';

    home.file =
      {".agents/pstack/agents".source = inputs.pstack + "/pstack/agents";}
      # Keep each skill as a directory link. Recursive links can write through
      # an old directory link into the read-only store when a skill adds files.
      // {".agents/skills".enable = false;}
      // perSkillSymlinks ".agents/skills"
      // perSkillSymlinks ".claude/skills"
      // perSkillSymlinks ".codex/skills"
      // perSkillSymlinks ".config/opencode/skills";
  };
}
