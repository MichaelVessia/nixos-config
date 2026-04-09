{...}: {
  # Worktrunk: CLI for git worktree management, designed for parallel AI agent
  # workflows. Package and shell integration come from the worktrunk flake's
  # homeModules.default, which is wired into home-manager.sharedModules for
  # flomac and framework13 in flake.nix.
  #
  # Shell integration installs a zsh function that lets `wt switch` change the
  # current shell's working directory (a plain binary can't cd its parent).
  programs.worktrunk = {
    enable = true;
    enableZshIntegration = true;
  };
}
