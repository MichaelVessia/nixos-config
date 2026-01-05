#!/usr/bin/env bash
# Manage sleep inhibitor for Claude Code sessions
# Usage: claude-sleep-inhibit start|stop|status
# Supports Linux (systemd-inhibit) and macOS (Amphetamine)

PIDFILE="/tmp/claude-sleep-inhibit.pid"
LOCKNAME="Claude Code session"
OS="$(uname -s)"

start_linux() {
    # Already running? Do nothing (idempotent)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        exit 0
    fi

    # Start inhibitor in background, fully detached with no inherited fds
    systemd-inhibit --what=sleep:idle --who="claude-code" --why="$LOCKNAME" sleep infinity </dev/null >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
}

start_darwin() {
    osascript -e 'tell application "Amphetamine" to start new session' >/dev/null 2>&1
}

stop_linux() {
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
}

stop_darwin() {
    osascript -e 'tell application "Amphetamine" to end session' >/dev/null 2>&1
}

status_linux() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "active"
        exit 0
    else
        echo "inactive"
        exit 1
    fi
}

status_darwin() {
    if osascript -e 'tell application "Amphetamine" to return session is active' 2>/dev/null | grep -q "true"; then
        echo "active"
        exit 0
    else
        echo "inactive"
        exit 1
    fi
}

case "$OS" in
    Linux)
        case "${1:-}" in
            start)  start_linux ;;
            stop)   stop_linux ;;
            status) status_linux ;;
            *)      echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
        esac
        ;;
    Darwin)
        case "${1:-}" in
            start)  start_darwin ;;
            stop)   stop_darwin ;;
            status) status_darwin ;;
            *)      echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
        esac
        ;;
    *)
        echo "Unsupported OS: $OS" >&2
        exit 1
        ;;
esac
