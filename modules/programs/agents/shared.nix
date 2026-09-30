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
  # pstack skills that BB workers use. poteto-mode holds every playbook; the
  # shared instructions list the playbooks that stay off. Omitted: arena,
  # interrogate, swarm (BB task threads replace subagent fan-out); unslop,
  # technical-writing, no-comments (STE and repo comment rules win);
  # babysit (drives PRs to merge); setup-pstack (BB sets models per thread);
  # reflect, automate-me, recall (transcript mining and skill rewrites);
  # typescript-best-practices (coding-standards wins); bro (personal skill of
  # the same name); principle-never-block-on-the-human (conflicts with the
  # stop rules). The personal pstack-bb skill maps each omitted step.
  pstackSkillsPath = inputs.pstack + "/plugins/pstack/skills";
  pstackSkillNames = [
    "architect"
    "blast-radius"
    "create-verification-skill"
    "deslop"
    "figure-it-out"
    "fix-ci"
    "fix-merge-conflicts"
    "get-pr-comments"
    "how"
    "maintain-verification-skill"
    "make-pr-easy-to-review"
    "poteto-mode"
    "principle-attack-the-premise"
    "principle-boundary-discipline"
    "principle-build-the-lever"
    "principle-encode-lessons-in-structure"
    "principle-exhaust-the-design-space"
    "principle-experience-first"
    "principle-fix-root-causes"
    "principle-foundational-thinking"
    "principle-guard-the-context-window"
    "principle-laziness-protocol"
    "principle-make-operations-idempotent"
    "principle-migrate-callers-then-delete-legacy-apis"
    "principle-minimize-reader-load"
    "principle-model-the-domain"
    "principle-outcome-oriented-execution"
    "principle-prove-it-works"
    "principle-redesign-from-first-principles"
    "principle-separate-before-serializing-shared-state"
    "principle-sequence-verifiable-units"
    "principle-subtract-before-you-add"
    "principle-test-behavior-not-implementation"
    "principle-type-system-discipline"
    "show-me-your-work"
    "teach"
    "thermo-nuclear-code-quality-review"
    "what-did-i-get-done"
    "why"
  ];
  # An unmanaged ~/.agents/skills/tdd (mattpocock/skills) owns the name, so
  # pstack's tdd installs as pstack-tdd with a matching frontmatter name.
  pstackTdd = "pstack-tdd";
  renamePstackTdd = {original, ...}: let
    renamed = builtins.replaceStrings ["---\nname: tdd\n"] ["---\nname: ${pstackTdd}\n"] original;
  in
    if renamed == original
    then throw "pstack tdd/SKILL.md no longer starts with `name: tdd`"
    else renamed;
  catalogSkillNames = enabledPersonalSkillNames ++ enabledGoogleWorkspaceSkillNames ++ pstackSkillNames;
  skillNames = catalogSkillNames ++ [pstackTdd];

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
        # Discovery rejects duplicate IDs across sources, so only the selected
        # names are discovered (pstack's bro would collide with ours).
        pstack = {
          path = pstackSkillsPath;
          filter.nameRegex = lib.concatStringsSep "|" pstackSkillNames;
        };
      };
      skills.enable = catalogSkillNames;
      skills.explicit.${pstackTdd} = {
        from = "pstack";
        path = "tdd";
        transform = renamePstackTdd;
      };
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
