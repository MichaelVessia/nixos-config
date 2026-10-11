# T3 Code server helpers
#
# The desktop app reuses the server named in userdata/server-runtime.json. If
# that server does not answer in time (for example, during a service restart),
# the app starts its own "managed" server over SSH. That server overwrites
# server-runtime.json, so the app never returns to t3code.service, and each
# reconnect kills and restarts the managed server. Two servers on one SQLite
# database also cause lock timeouts and event loop stalls, which drop clients.
#
# t3guard runs when server-runtime.json changes and every 30 seconds, because
# newer servers do not always rewrite that file. If t3code.service is enabled,
# it stops SSH-launched servers and points server-runtime.json back to the
# service, so the next reconnect reuses the service.
#
# t3update updates through `t3 update`. Without the service, it stops
# SSH-launched servers, and the desktop app starts the new version when it
# connects.
#
# Usage:
#   ssh forge t3update
{
  lib,
  pkgs,
  ...
}: let
  # Stops servers that the desktop app started over SSH, outside the service.
  stopSshServers = ''
    stopped_pids=""
    for dir in "$t3_home"/ssh-launch/*/; do
      [ "$(cat "$dir/managed" 2>/dev/null)" = managed ] || continue
      pid="$(cat "$dir/pid" 2>/dev/null)" || continue
      [ -r "/proc/$pid/cmdline" ] || continue
      tr '\0' ' ' <"/proc/$pid/cmdline" | grep -q "/t3 serve" || continue
      grep -q t3code.service "/proc/$pid/cgroup" && continue
      echo "Stopping SSH-launched t3 server (pid $pid)"
      kill "$pid"
      stopped_pids="$stopped_pids $pid"
    done
    for pid in $stopped_pids; do
      for _ in $(seq 300); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
    done
  '';

  t3guard = pkgs.writeShellApplication {
    name = "t3guard";
    runtimeInputs = [pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.iproute2 pkgs.jq pkgs.procps pkgs.systemd];
    text = ''
      t3_home="''${T3CODE_HOME:-$HOME/.t3}"
      runtime="$t3_home/userdata/server-runtime.json"

      systemctl --user is-enabled --quiet t3code.service 2>/dev/null || exit 0

      ${stopSshServers}

      cgroup="$(systemctl --user show -p ControlGroup --value t3code.service)"
      [ -n "$cgroup" ] || exit 0
      service_pid=""
      while read -r pid; do
        if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "/t3 serve"; then
          service_pid="$pid"
          break
        fi
      done <"/sys/fs/cgroup$cgroup/cgroup.procs"
      # A starting service writes server-runtime.json itself.
      [ -n "$service_pid" ] || exit 0
      port="$(ss -ltnpH | grep "pid=$service_pid," | awk '{print $4}' | grep -oE '[0-9]+$' | head -1 || true)"
      [ -n "$port" ] || exit 0

      [ "$(jq -r .pid "$runtime" 2>/dev/null)" = "$service_pid" ] && exit 0
      echo "Pointing $runtime to t3code.service (pid $service_pid, port $port)"
      started="$(date -u -d "$(ps -o lstart= -p "$service_pid")" +%Y-%m-%dT%H:%M:%S.000Z)"
      jq -cn --argjson pid "$service_pid" --argjson port "$port" --arg started "$started" \
        '{version: 1, pid: $pid, host: "127.0.0.1", port: $port, origin: "http://127.0.0.1:\($port)", startedAt: $started}' \
        >"$runtime.tmp"
      mv "$runtime.tmp" "$runtime"
    '';
  };

  t3update = pkgs.writeShellApplication {
    name = "t3update";
    runtimeInputs = [pkgs.coreutils pkgs.gawk pkgs.gnugrep pkgs.iproute2 pkgs.jq pkgs.procps t3guard];
    text = ''
      t3_home="''${T3CODE_HOME:-$HOME/.t3}"
      version="$(jq -r .activeVersion "$t3_home/runtime/service-state.json")"
      t3="$t3_home/runtime/versions/$version/t3"
      if [ ! -x "$t3" ]; then
        echo "t3update: no t3 binary at $t3" >&2
        exit 1
      fi

      "$t3" update "$@"

      if ! systemctl --user cat t3code.service >/dev/null 2>&1; then
        ${stopSshServers}
        echo "No t3code.service. The desktop app starts the new version when it connects."
        exit 0
      fi

      pattern="$t3_home/runtime/versions/[^ ]+/t3 serve"
      for _ in $(seq 30); do
        t3guard
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
    home.packages = [t3guard t3update];

    systemd.user.paths.t3guard = {
      Unit.Description = "Keep T3 Code clients on t3code.service";
      Path.PathChanged = "%h/.t3/userdata/server-runtime.json";
      Install.WantedBy = ["default.target"];
    };

    systemd.user.timers.t3guard = {
      Unit.Description = "Check for SSH-launched T3 Code servers";
      Timer = {
        OnStartupSec = "30s";
        OnUnitActiveSec = "30s";
      };
      Install.WantedBy = ["timers.target"];
    };

    systemd.user.services.t3guard = {
      Unit.Description = "Stop SSH-launched T3 Code servers";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe t3guard;
      };
    };
  };
}
