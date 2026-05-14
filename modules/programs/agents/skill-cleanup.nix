{lib, ...}: let
  legacyBackupSkills = [
    "deslop"
    "diagnose"
    "grill-me"
    "grill-with-docs"
    "improve-codebase-architecture"
    "tdd"
    "to-issues"
    "to-prd"
  ];
in {
  config.home.activation.disableLegacyBackupSkillManifests = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for skill in ${lib.escapeShellArgs legacyBackupSkills}; do
      backup_dir="$HOME/.agents/skills/$skill.backup"
      if [ -f "$backup_dir/SKILL.md" ]; then
        $DRY_RUN_CMD mv "$backup_dir/SKILL.md" "$backup_dir/SKILL.md.disabled"
      fi
    done
  '';
}
