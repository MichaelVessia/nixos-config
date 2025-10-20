#!/usr/bin/env bash
# Claude Code statusline script
# Shows model, current directory, and git status with color coding

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir' | sed "s|$HOME|~|")
model=$(echo "$input" | jq -r '.model.display_name')
git_info=""

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        if [ "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]; then
            # Dirty repo - yellow branch name with asterisk
            git_info=$(printf " \033[33m(%s*)\033[0m" "$branch")
        else
            # Clean repo - green branch name
            git_info=$(printf " \033[32m(%s)\033[0m" "$branch")
        fi
    fi
fi

# Format: model (dim) + directory (blue) + git info (colored)
printf "\033[2m%s\033[0m \033[34m%s\033[0m%s\n" "$model" "$cwd" "$git_info"
