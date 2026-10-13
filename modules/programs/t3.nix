# T3 Code server settings
#
# T3 writes and updates t3code.service itself, so these settings are drop-ins
# that survive its updates.
#
# T3 binds 3773 when it is free and a random port otherwise (for example,
# while another server holds 3773). T3CODE_TAILSCALE_SERVE makes the server
# point Tailscale Serve at its current port on each start.
#
# T3 runs agents in app-t3code-agents.slice. Each server start sets that
# slice's memory limits near total RAM with `systemctl set-property --runtime`,
# which overrides drop-ins on that slice. When agents fill RAM, the server
# stalls on swap, clients drop, and the desktop app starts extra servers over
# SSH on the same database. So the cap is on the parent app-t3code.slice, which
# T3 does not change. The cap is hard, with little swap, so the kernel kills
# the largest agent process (usually a test worker). MemoryHigh throttles
# instead: the agents swap without end, and the disk I/O stalls the server too.
#
# The server itself leaks memory (35G after a day), and t3code.service is
# outside app-t3code.slice. So the service has its own hard cap: the kernel
# kills the server and Restart=always starts a new one, instead of letting it
# stall on swap.
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
      MemoryMax=8G
      MemorySwapMax=1G
    '';

    xdg.configFile."systemd/user/app-t3code.slice.d/90-nix.conf".text = ''
      [Slice]
      MemoryMax=60%
      MemorySwapMax=1G
    '';
  };
}
