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
  gwsSkillsPath = inputs.googleworkspace-cli + "/skills";
  personalSkillNames = dirNames ./shared/skills;
  enabledGoogleWorkspaceSkillNames = [
    "gws-calendar"
    "gws-calendar-agenda"
    "gws-calendar-insert"
    "gws-docs"
    "gws-docs-write"
    "gws-drive"
    "gws-drive-upload"
    "gws-gmail"
    "gws-gmail-forward"
    "gws-gmail-read"
    "gws-gmail-reply"
    "gws-gmail-reply-all"
    "gws-gmail-send"
    "gws-gmail-triage"
    "gws-gmail-watch"
    "gws-meet"
    "gws-shared"
    "gws-sheets"
    "gws-sheets-append"
    "gws-sheets-read"
    "gws-slides"
  ];
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

  # Upstream pstack skills (no plugin, agents, or hooks). Its bro and tdd share names
  # with other skills (the personal bro, an unmanaged ~/.agents/skills/tdd),
  # so they install as pstack-bro and pstack-tdd with a matching frontmatter
  # name. Discovery rejects duplicate IDs, so the renamed pair is not
  # discovered under the original names.
  pstackSkillsPath = inputs.pstack + "/pstack/skills";
  pstackRenamed = ["bro" "tdd"];
  pstackNormalized = {
    poteto-mode = "Poteto Mode";
    make-bot-ui = "Make Bot UI";
  };
  pstackExplicitNames = pstackRenamed ++ lib.attrNames pstackNormalized;
  pstackSkillId = name:
    if lib.elem name pstackRenamed
    then "pstack-${name}"
    else name;
  pstackSkillNames = lib.subtractLists pstackExplicitNames (dirNames pstackSkillsPath);
  renamePstackSkill = name: {original, ...}: let
    originalName = pstackNormalized.${name} or name;
    renamed = builtins.replaceStrings ["---\nname: ${originalName}\n"] ["---\nname: ${pstackSkillId name}\n"] original;
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
  catalogSkillNames = enabledPersonalSkillNames ++ enabledGoogleWorkspaceSkillNames ++ pstackSkillNames ++ teamKitSkillNames;
  skillNames = catalogSkillNames ++ map pstackSkillId pstackExplicitNames;

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
        googleworkspace.path = gwsSkillsPath;
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
          name = pstackSkillId name;
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
