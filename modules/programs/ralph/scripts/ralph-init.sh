#!/usr/bin/env bash
# ralph-init: Scaffold a Ralph autonomous coding agent setup in the current directory
set -e

RALPH_DIR="ralph"

if [ -d "$RALPH_DIR" ]; then
  echo "Error: ralph/ directory already exists"
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

echo "Creating Ralph scaffolding..."

mkdir -p "$RALPH_DIR/scripts"
mkdir -p "docs/prds"

# Add local Ralph artifacts to git excludes (local, doesn't modify .gitignore)
GIT_DIR=$(git rev-parse --git-dir)
if ! grep -q "^\.ralph-auto/$" "$GIT_DIR/info/exclude" 2>/dev/null; then
  echo ".ralph-auto/" >> "$GIT_DIR/info/exclude"
fi

# Copy scripts from nix store (paths injected by Nix)
cp "@scriptsDir@/ralph-auto-core.sh" "$RALPH_DIR/ralph-auto-core.sh"
cp "@scriptsDir@/ralph-auto-claude.sh" "$RALPH_DIR/ralph-auto-claude.sh"
cp "@scriptsDir@/ralph-auto-codex.sh" "$RALPH_DIR/ralph-auto-codex.sh"
cp "@scriptsDir@/ci-check.sh" "$RALPH_DIR/scripts/ci-check.sh"
cp "@scriptsDir@/stream-filter.sh" "$RALPH_DIR/scripts/stream-filter.sh"

# Copy templates from nix store
cp "@templatesDir@/HOW_TO_RALPH.md" "$RALPH_DIR/HOW_TO_RALPH.md"
cp "@templatesDir@/ralph-auto-claude.jsonc" "$RALPH_DIR/ralph-auto-claude.jsonc"
cp "@templatesDir@/ralph-auto-codex.jsonc" "$RALPH_DIR/ralph-auto-codex.jsonc"

# Make files writable (nix store files are read-only)
chmod u+w "$RALPH_DIR/HOW_TO_RALPH.md"
chmod u+w "$RALPH_DIR/ralph-auto-claude.jsonc"
chmod u+w "$RALPH_DIR/ralph-auto-codex.jsonc"

# Make scripts executable and writable (nix store files are read-only)
chmod u+wx "$RALPH_DIR/ralph-auto-core.sh"
chmod u+wx "$RALPH_DIR/ralph-auto-claude.sh"
chmod u+wx "$RALPH_DIR/ralph-auto-codex.sh"
chmod u+wx "$RALPH_DIR/scripts/ci-check.sh"
chmod u+wx "$RALPH_DIR/scripts/stream-filter.sh"

echo ""
echo "Ralph scaffolding created!"
echo ""
echo "Next steps:"
echo "  1. Edit ralph/ralph-auto-claude.jsonc and ralph/ralph-auto-codex.jsonc"
echo "  2. Ensure specs exist in docs/prds/"
echo "  3. Run ./ralph/ralph-auto-claude.sh \"<focus prompt>\""
echo "  4. Or run ./ralph/ralph-auto-codex.sh \"<focus prompt>\""
