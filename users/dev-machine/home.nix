{
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  imports = [
    ../common.nix
    ../../modules/programs/agents/options.nix
    ../../modules/programs/agents/shared.nix
    ../../modules/programs/agents/claude-code
    ../../modules/programs/agents/codex.nix
    ../../modules/programs/agents/cursor.nix
    ../../modules/programs/git.nix
    ../../modules/programs/shell.nix
    ../../modules/programs/zellij.nix
    ../../modules/programs/ssh.nix
    ../../modules/programs/vaults.nix
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

  # shell.nix defaults to nvim, which comes from nvf. NixOS installs nano.
  home.sessionVariables = {
    EDITOR = lib.mkForce "nano";
    VISUAL = lib.mkForce "nano";
    # agent-browser does not search PATH for Chrome, and its downloaded
    # Chrome does not run on NixOS.
    AGENT_BROWSER_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
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
    python3
    awscli2
    pkgs-unstable.devbox # repos pin devbox.lock to newer releases than stable ships
    (pkgs-unstable.callPackage ../../modules/programs/pup {}) # Datadog API CLI; needs newer rustc than 25.11 ships
    inputs.llm-agents.packages.${pkgs.system}.agent-browser
    inputs.llm-agents.packages.${pkgs.system}.claude-code
    inputs.llm-agents.packages.${pkgs.system}.herdr
  ];
}
