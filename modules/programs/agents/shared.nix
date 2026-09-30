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

  # pstack skills from the pinned pstack-claude port, installed as portable
  # skill content (no plugin, agents, or hooks). Its bro and tdd share names
  # with other skills (the personal bro, an unmanaged ~/.agents/skills/tdd),
  # so they install as pstack-bro and pstack-tdd with a matching frontmatter
  # name. Discovery rejects duplicate IDs, so the renamed pair is not
  # discovered under the original names.
  pstackSkillsPath = inputs.pstack + "/plugins/pstack/skills";
  pstackRenamed = ["bro" "tdd"];
  pstackSkillNames = lib.subtractLists pstackRenamed (dirNames pstackSkillsPath);
  renamePstackSkill = name: {original, ...}: let
    renamed = builtins.replaceStrings ["---\nname: ${name}\n"] ["---\nname: pstack-${name}\n"] original;
  in
    if renamed == original
    then throw "pstack ${name}/SKILL.md no longer starts with `name: ${name}`"
    else renamed;
  catalogSkillNames = enabledPersonalSkillNames ++ enabledGoogleWorkspaceSkillNames ++ pstackSkillNames;
  skillNames = catalogSkillNames ++ map (name: "pstack-${name}") pstackRenamed;

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
      };
      skills.enable = catalogSkillNames;
      skills.explicit = lib.listToAttrs (map (name: {
          name = "pstack-${name}";
          value = {
            from = "pstack";
            path = name;
            transform = renamePstackSkill name;
          };
        })
        pstackRenamed);
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

    home.activation.removeLegacyPerToolSkillDirLinks = lib.hm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
      for dir in ${lib.escapeShellArgs perToolSkillDirs}; do
        path="$HOME/$dir"
        if [ -L "$path" ]; then
          $DRY_RUN_CMD rm "$path"
        fi
      done
    '';

    home.file =
      perSkillSymlinks ".claude/skills"
      // perSkillSymlinks ".codex/skills"
      // perSkillSymlinks ".config/opencode/skills";
  };
}
