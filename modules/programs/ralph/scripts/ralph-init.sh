#!/usr/bin/env bash
# ralph-init: Scaffold a Ralph autonomous coding agent setup in the current directory
set -e

RALPH_DIR="ralph"

RESCAFFOLD=false
if [ -d "$RALPH_DIR" ]; then
  RESCAFFOLD=true
  echo "ralph/ directory already exists, re-scaffolding..."
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: Not in a git repository"
  exit 1
fi

echo "Creating Ralph scaffolding..."

mkdir -p "$RALPH_DIR/scripts"
mkdir -p ".ralph"

# Add .ralph/ to git excludes (local, doesn't modify .gitignore)
# In worktrees, git-dir points to .git/worktrees/<name> which may lack info/exclude.
# Fall back to the main repo's info/exclude.
GIT_DIR=$(git rev-parse --git-dir)
EXCLUDE_FILE="$GIT_DIR/info/exclude"
if [ ! -d "$GIT_DIR/info" ]; then
  COMMON_DIR=$(git rev-parse --git-common-dir)
  EXCLUDE_FILE="$COMMON_DIR/info/exclude"
fi
mkdir -p "$(dirname "$EXCLUDE_FILE")"
if ! grep -q "^\.ralph/$" "$EXCLUDE_FILE" 2>/dev/null; then
  echo ".ralph/" >> "$EXCLUDE_FILE"
fi

# Helper: copy file only if it doesn't already exist (preserves user edits on re-scaffold)
copy_if_new() {
  local src="$1" dest="$2"
  if [ "$RESCAFFOLD" = true ] && [ -f "$dest" ]; then
    echo "  keeping $dest (user-customized)"
    return
  fi
  cp "$src" "$dest"
}

# Infrastructure scripts (always overwritten, not user-edited)
cp "@scriptsDir@/ralph.sh" "$RALPH_DIR/ralph.sh"
cp "@scriptsDir@/prd-status.sh" "$RALPH_DIR/scripts/prd-status.sh"
cp "@scriptsDir@/prd-update.sh" "$RALPH_DIR/scripts/prd-update.sh"
cp "@scriptsDir@/stream-filter.sh" "$RALPH_DIR/scripts/stream-filter.sh"

# User-customizable files (preserved on re-scaffold)
copy_if_new "@scriptsDir@/ci-check.sh" "$RALPH_DIR/scripts/ci-check.sh"
copy_if_new "@templatesDir@/RALPH_PROMPT.md" "$RALPH_DIR/RALPH_PROMPT.md"
copy_if_new "@templatesDir@/prd.json" "$RALPH_DIR/prd.json"
copy_if_new "@templatesDir@/progress.txt" "$RALPH_DIR/progress.txt"

# HOW_TO_RALPH.md is reference docs, always update it
cp "@templatesDir@/HOW_TO_RALPH.md" "$RALPH_DIR/HOW_TO_RALPH.md"

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
