{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs/agents/options.nix
    ../../modules/programs/agents/shared.nix
    ../../modules/programs/agents/claude-code
    ../../modules/programs/agents/codex.nix
    ../../modules/programs/git.nix
    ../../modules/programs/shell.nix
    ../../modules/programs/zellij.nix
    ../../modules/programs/ssh.nix
    ../../modules/programs/vaults.nix
    ../../modules/programs/t3.nix
    ../../modules/programs/worktrunk.nix
  ];

  scripts.groups = ["file-management" "git" "process-management"];

  agentSkills.personal = [
    "agent-browser"
    "effect-service-design"
    "gh-comment"
    "herdr"
    "herdr-dispatch"
    "pstack-sync"
  ];

  # Agents write notes to a local work vault. Syncthing does not run here, so
  # the notes stay on this machine.
  vaults = {
    deviceName = "dev-machine";
    profile = "work";
  };

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";

  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    curl
    btop
    difftastic
    inputs.llm-agents.packages.${pkgs.system}.claude-code
    inputs.llm-agents.packages.${pkgs.system}.herdr
  ];
}
