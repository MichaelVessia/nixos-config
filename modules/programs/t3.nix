# T3 Code server settings
#
# T3 writes and updates t3code.service itself, so these settings are drop-ins
# that survive its updates.
#
# T3 binds 3773 when it is free and a random port otherwise (for example,
# while another server holds 3773). T3CODE_TAILSCALE_SERVE makes the server
# point Tailscale Serve at its current port on each start.
#
# T3 runs agents in app-t3code-agents.slice and sets that slice's memory limits
# near total RAM. When agents fill RAM, the server stalls on swap, clients drop,
# and the desktop app starts extra servers over SSH on the same database. These
# drop-ins sort after T3's 50-Memory*.conf, cap the agents well below RAM, and
# reserve memory for the server. The cap is hard, with little swap, so the
# kernel kills the largest agent process (usually a test worker). MemoryHigh
# throttles instead: the agents swap without end, and the disk I/O stalls the
# server too.
{
  lib,
  pkgs,
  ...
}: {
  config = lib.mkIf pkgs.stdenv.isLinux {
    xdg.configFile."systemd/user/t3code.service.d/90-nix.conf".text = ''
      [Service]
      Environment=T3CODE_TAILSCALE_SERVE=true
      MemoryLow=2G
    '';

    xdg.configFile."systemd/user/app-t3code-agents.slice.d/90-nix.conf".text = ''
      [Slice]
      MemoryHigh=infinity
      MemoryMax=60%
      MemorySwapMax=1G
    '';
  };
}
