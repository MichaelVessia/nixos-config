#!/usr/bin/env bash
# Manage sleep inhibitor for Claude Code sessions
# Usage: claude-sleep-inhibit start|stop|status

PIDFILE="/tmp/claude-sleep-inhibit.pid"
LOCKNAME="Claude Code session"

start() {
    # Already running? Do nothing (idempotent)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        exit 0
    fi

    # Start inhibitor in background
    systemd-inhibit --what=sleep:idle --who="claude-code" --why="$LOCKNAME" sleep infinity &
    echo $! > "$PIDFILE"
}

stop() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
}

status() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "active"
        exit 0
    else
        echo "inactive"
        exit 1
    fi
}

case "${1:-}" in
    start)  start ;;
    stop)   stop ;;
    status) status ;;
    *)      echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
esac
