#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

# Extract model information
model_name=$(echo "$input" | jq -r '.model.id // "unknown"')

# Extract directory information
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Extract context usage
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
usage=$(echo "$input" | jq '.context_window.current_usage')
if [ "$usage" != "null" ] && [ "$context_size" -gt 0 ] 2>/dev/null; then
  # Include input_tokens + cache tokens for actual context usage
  current_tokens=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
  if [ "$current_tokens" != "null" ] && [ "$current_tokens" -ge 0 ] 2>/dev/null; then
    context_pct=$((current_tokens * 100 / context_size))
  else
    context_pct="-"
  fi
else
  context_pct="-"
fi

# Get git branch if in a git repo (using -C to avoid cd)
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

# Get basename of directory
dir_name=$(basename "$cwd")

# ============================================
# HELPER FUNCTIONS
# ============================================

# Powerline arrow character (U+E0B0)
PL_ARROW=""

# Powerline segment: bg color, fg color, text, next segment's bg color
# Uses 256-color ANSI codes
pl_segment() {
  local bg=$1 fg=$2 text=$3 next_bg=$4
  # Background + foreground for text, then transition arrow
  printf "\033[48;5;%dm\033[38;5;%dm %s \033[48;5;%dm\033[38;5;%dm%s" \
    "$bg" "$fg" "$text" "$next_bg" "$bg" "$PL_ARROW"
}

# Final powerline segment (no arrow, just reset)
pl_segment_end() {
  local bg=$1 fg=$2 text=$3
  printf "\033[48;5;%dm\033[38;5;%dm %s \033[0m\033[38;5;%dm%s\033[0m" \
    "$bg" "$fg" "$text" "$bg" "$PL_ARROW"
}

# ============================================
# BUILD THE POWERLINE STATUS LINE
# ============================================

# Color definitions (256-color palette)
C_MAGENTA=5 # Model
C_YELLOW=3  # Project
C_GREEN=2   # Branch
C_CYAN=6    # Context
C_BLACK=0   # Dark text

# Shorten model name (e.g., "claude-sonnet-4-5-20250929" → "sonnet-4-5")
short_model=$(echo "$model_name" | sed 's/^claude-//' | sed 's/-[0-9]\{8\}$//')

# Build status line: Model → Project → Branch → Context%
row1=$(pl_segment $C_MAGENTA $C_BLACK "$short_model" $C_YELLOW)
# Format context display (add % only if it's a number)
if [ "$context_pct" = "-" ]; then
  context_display="$context_pct"
else
  context_display="${context_pct}%"
fi

if [ -n "$branch" ]; then
  row1="${row1}$(pl_segment $C_YELLOW $C_BLACK "$dir_name" $C_GREEN)"
  row1="${row1}$(pl_segment $C_GREEN $C_BLACK "$branch" $C_CYAN)"
  row1="${row1}$(pl_segment_end $C_CYAN $C_BLACK "$context_display")"
else
  row1="${row1}$(pl_segment $C_YELLOW $C_BLACK "$dir_name" $C_CYAN)"
  row1="${row1}$(pl_segment_end $C_CYAN $C_BLACK "$context_display")"
fi
printf "%b\n" "$row1"
