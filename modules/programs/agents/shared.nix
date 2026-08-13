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
  googleWorkspaceSkillNames = dirNames gwsSkillsPath;
  homelabSkillNames = [
    "adguard"
    "autocaliweb"
    "caddy"
    "freshrss"
    "home-assistant-manager"
    "homepage-add"
    "immich"
    "jellyfin"
    "jellyseerr"
    "paperless"
    "prowlarr"
    "proxmox"
    "radarr"
    "sabnzbd"
    "sonarr"
    "tailscale"
    "tubearchivist"
    "uptime-kuma"
  ];
  enabledPersonalSkillNames =
    if enableHomelabSkills
    then personalSkillNames
    else lib.subtractLists homelabSkillNames personalSkillNames;
  skillNames = enabledPersonalSkillNames ++ googleWorkspaceSkillNames;

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
      };
      skills = {
        enable = enabledPersonalSkillNames;
        enableAll = ["googleworkspace"];
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
