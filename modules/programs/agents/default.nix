# Every harness. Hosts that need fewer import options.nix, shared.nix, and the
# harness modules they use.
{
  imports = [
    ./options.nix
    ./shared.nix
    ./agentsview.nix
    ./codex.nix
    ./opencode.nix
    ./omp
    ./pi
    ./plannotator.nix
    ./claude-code
  ];
}
