# Memory protection for hosts that run parallel coding agents.
#
# Agent type checks and linters can fill RAM. zram absorbs short spikes
# faster than disk swap. earlyoom kills checkers before RAM and swap run out,
# so SSH, Tailscale, T3 Code, and the agents stay alive. earlyoom matches
# /proc/<pid>/comm: the T3 server is node-MainThread and Claude Code is
# .claude-wrapped.
{
  zramSwap.enable = true;

  services.earlyoom = {
    enable = true;
    freeSwapThreshold = 20;
    extraArgs = [
      "--prefer"
      "^(tsc|tsgolint|jest-worker|oxlint)$"
      "--avoid"
      "^(sshd|sshd-session|tailscaled|node-MainThread|\\.claude-wrapped|systemd|systemd-journal|systemd-logind)$"
    ];
  };
}
