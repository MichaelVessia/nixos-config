{...}: let
  sharedInstructions = builtins.readFile ./shared/instructions.md;
in {
  config.home.file.".config/opencode/AGENTS.md".text = sharedInstructions;
}
