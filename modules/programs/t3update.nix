# t3update - update T3 Code through its background service
#
# Updating from the desktop app can start an extra server over SSH next to
# t3code.service. This updates through `t3 update`, stops SSH-launched
# servers, and checks that one server remains.
#
# Usage:
#   ssh forge t3update
{
  lib,
  pkgs,
  ...
}: let
  t3update = pkgs.writeShellApplication {
    name = "t3update";
    runtimeInputs = [pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.iproute2 pkgs.jq pkgs.procps];
    text = ''
      t3_home="''${T3CODE_HOME:-$HOME/.t3}"
      version="$(jq -r .activeVersion "$t3_home/runtime/service-state.json")"
      t3="$t3_home/runtime/versions/$version/t3"
      if [ ! -x "$t3" ]; then
        echo "t3update: no t3 binary at $t3" >&2
        exit 1
      fi

      "$t3" update "$@"

      stopped=0
      for dir in "$t3_home"/ssh-launch/*/; do
        [ "$(cat "$dir/managed" 2>/dev/null)" = managed ] || continue
        pid="$(cat "$dir/pid" 2>/dev/null)" || continue
        [ -r "/proc/$pid/cmdline" ] || continue
        tr '\0' ' ' <"/proc/$pid/cmdline" | grep -q "/t3 serve" || continue
        grep -q t3code.service "/proc/$pid/cgroup" && continue
        echo "Stopping SSH-launched t3 server (pid $pid)"
        kill "$pid"
        stopped=1
      done

      if [ "$stopped" = 1 ]; then
        sleep 2
        systemctl --user restart t3code.service
      fi

      pattern="$t3_home/runtime/versions/[^ ]+/t3 serve"
      for _ in $(seq 30); do
        pids="$(pgrep -f "$pattern" || true)"
        [ -n "$pids" ] && ss -ltnp | grep -q "pid=$(echo "$pids" | head -1)," && break
        sleep 1
      done

      count="$(echo "$pids" | grep -c . || true)"
      echo "t3 servers running: $count"
      for pid in $pids; do
        echo "  $(ps -o pid=,args= -p "$pid")"
        ss -ltnp | grep "pid=$pid," | awk '{print "    listening on " $4}'
      done
      [ "$count" = 1 ]
    '';
  };
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [t3update];
  };
}
