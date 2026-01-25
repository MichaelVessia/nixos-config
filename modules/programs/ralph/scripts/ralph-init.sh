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
mkdir -p ".ralph"

# Add .ralph/ to git excludes (local, doesn't modify .gitignore)
GIT_DIR=$(git rev-parse --git-dir)
if ! grep -q "^\.ralph/$" "$GIT_DIR/info/exclude" 2>/dev/null; then
  echo ".ralph/" >> "$GIT_DIR/info/exclude"
fi

# Copy scripts from nix store (paths injected by Nix)
cp "@scriptsDir@/ralph.sh" "$RALPH_DIR/ralph.sh"
cp "@scriptsDir@/ci-check.sh" "$RALPH_DIR/scripts/ci-check.sh"
cp "@scriptsDir@/prd-status.sh" "$RALPH_DIR/scripts/prd-status.sh"
cp "@scriptsDir@/prd-update.sh" "$RALPH_DIR/scripts/prd-update.sh"
cp "@scriptsDir@/stream-filter.sh" "$RALPH_DIR/scripts/stream-filter.sh"

# Copy templates from nix store
cp "@templatesDir@/RALPH_PROMPT.md" "$RALPH_DIR/RALPH_PROMPT.md"
cp "@templatesDir@/HOW_TO_RALPH.md" "$RALPH_DIR/HOW_TO_RALPH.md"
cp "@templatesDir@/prd.json" "$RALPH_DIR/prd.json"
cp "@templatesDir@/progress.txt" "$RALPH_DIR/progress.txt"

# Make files writable (nix store files are read-only)
chmod u+w "$RALPH_DIR/RALPH_PROMPT.md"
chmod u+w "$RALPH_DIR/HOW_TO_RALPH.md"
chmod u+w "$RALPH_DIR/prd.json"
chmod u+w "$RALPH_DIR/progress.txt"

# Make scripts executable and writable (nix store files are read-only)
chmod u+wx "$RALPH_DIR/ralph.sh"
chmod u+wx "$RALPH_DIR/scripts/ci-check.sh"
chmod u+wx "$RALPH_DIR/scripts/prd-status.sh"
chmod u+wx "$RALPH_DIR/scripts/prd-update.sh"
chmod u+wx "$RALPH_DIR/scripts/stream-filter.sh"

echo ""
echo "Ralph scaffolding created!"
echo ""
echo "Next steps:"
echo "  1. Edit ralph/prd.json with your stories"
echo "  2. Edit ralph/scripts/ci-check.sh with your CI commands"
echo "  3. Optionally customize ralph/RALPH_PROMPT.md"
echo "  4. Run ./ralph/scripts/prd-status.sh to see status"
echo "  5. Run ./ralph/ralph.sh to start the loop"
