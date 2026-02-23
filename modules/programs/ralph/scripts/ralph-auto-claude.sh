#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RALPH_AGENT="claude" \
RALPH_DEFAULT_CONFIG="ralph/ralph-auto-claude.jsonc" \
bash "$SCRIPT_DIR/ralph-auto-core.sh" "$@"
