# Every harness. Hosts that need fewer import options.nix, shared.nix, and the
# harness modules they use.
{
  imports = [
    ./options.nix
    ./shared.nix
    ./agentsview.nix
    ./codex.nix
    ./grok.nix
    ./opencode.nix
    ./pi
    ./plannotator.nix
    ./claude-code
  ];
}
