{
  config,
  pkgs,
  lib,
  ...
}: let
  # Wrapped scripts with explicit deps
  claude-statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [pkgs.jq pkgs.git pkgs.coreutils];
    text = ''
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
      branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)

      # Get basename of directory
      dir_name=$(basename "$cwd")

      # Powerline arrow character (U+E0B0)
      PL_ARROW=""

      # Powerline segment: bg color, fg color, text, next segment's bg color
      pl_segment() {
        local bg=$1 fg=$2 text=$3 next_bg=$4
        printf "\033[48;5;%dm\033[38;5;%dm %s \033[48;5;%dm\033[38;5;%dm%s" \
          "$bg" "$fg" "$text" "$next_bg" "$bg" "$PL_ARROW"
      }

      # Final powerline segment
      pl_segment_end() {
        local bg=$1 fg=$2 text=$3
        printf "\033[48;5;%dm\033[38;5;%dm %s \033[0m\033[38;5;%dm%s\033[0m" \
          "$bg" "$fg" "$text" "$bg" "$PL_ARROW"
      }

      # Color definitions (256-color palette)
      C_MAGENTA=5 # Model
      C_YELLOW=3  # Project
      C_GREEN=2   # Branch
      C_CYAN=6    # Context
      C_BLACK=0   # Dark text

      # Shorten model name (e.g., "claude-sonnet-4-5-20250929" -> "sonnet-4-5")
      short_model=$(echo "$model_name" | sed 's/^claude-//' | sed 's/-[0-9]\{8\}$//')

      # Build status line: Model -> Project -> Branch -> Context%
      row1=$(pl_segment $C_MAGENTA $C_BLACK "$short_model" $C_YELLOW)
      # Format context display (add % only if it's a number)
      if [ "$context_pct" = "-" ]; then
        context_display="$context_pct"
      else
        context_display="''${context_pct}%"
      fi

      if [ -n "$branch" ]; then
        row1="''${row1}$(pl_segment $C_YELLOW $C_BLACK "$dir_name" $C_GREEN)"
        row1="''${row1}$(pl_segment $C_GREEN $C_BLACK "$branch" $C_CYAN)"
        row1="''${row1}$(pl_segment_end $C_CYAN $C_BLACK "$context_display")"
      else
        row1="''${row1}$(pl_segment $C_YELLOW $C_BLACK "$dir_name" $C_CYAN)"
        row1="''${row1}$(pl_segment_end $C_CYAN $C_BLACK "$context_display")"
      fi
      printf "%b\n" "$row1"
    '';
  };

  claude-alert = pkgs.writeShellApplication {
    name = "claude-alert";
    runtimeInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.pipewire];
    text = ''
      if [[ "$(uname -s)" == "Darwin" ]]; then
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
      else
        pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null &
      fi
    '';
  };

  claude-notify = pkgs.writeShellApplication {
    name = "claude-notify";
    runtimeInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.pipewire];
    text = ''
      if [[ "$(uname -s)" == "Darwin" ]]; then
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
      else
        pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
      fi
    '';
  };

  claude-sleep-inhibit = pkgs.writeShellApplication {
    name = "claude-sleep-inhibit";
    runtimeInputs =
      [pkgs.coreutils]
      ++ lib.optionals pkgs.stdenv.isLinux [pkgs.systemd];
    text = ''
      PIDFILE="/tmp/claude-sleep-inhibit.pid"
      LOCKNAME="Claude Code session"
      OS="$(uname -s)"

      start_linux() {
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          exit 0
        fi
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
          case "''${1:-}" in
            start)  start_linux ;;
            stop)   stop_linux ;;
            status) status_linux ;;
            *)      echo "Usage: $0 {start|stop|status}" >&2; exit 1 ;;
          esac
          ;;
        Darwin)
          case "''${1:-}" in
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
    '';
  };

  git-safety-guard = pkgs.writers.writePython3Bin "git-safety-guard" {flakeIgnore = ["E501"];} ''
    """
    Git/filesystem safety guard for Claude Code.

    Blocks destructive commands that can lose uncommitted work or delete files.
    This hook runs before Bash commands execute and can deny dangerous operations.

    Exit behavior:
      - Exit 0 with JSON {"hookSpecificOutput": {"permissionDecision": "deny", ...}} = block
      - Exit 0 with no output = allow
    """
    import json
    import re
    import sys

    # Destructive patterns to block - tuple of (regex, reason)
    DESTRUCTIVE_PATTERNS = [
        # Git commands that discard uncommitted changes
        (
            r"git\s+checkout\s+--\s+",
            "git checkout -- discards uncommitted changes permanently. Use 'git stash' first."
        ),
        (
            r"git\s+checkout\s+(?!-b\b)(?!--orphan\b)[^\s]+\s+--\s+",
            "git checkout <ref> -- <path> overwrites working tree. Use 'git stash' first."
        ),
        (
            r"git\s+restore\s+(?!--staged\b)(?!-S\b)",
            "git restore discards uncommitted changes. Use 'git stash' or 'git diff' first."
        ),
        (
            r"git\s+restore\s+.*(?:--worktree|-W\b)",
            "git restore --worktree/-W discards uncommitted changes permanently."
        ),
        # Git reset variants
        (
            r"git\s+reset\s+--hard",
            "git reset --hard destroys uncommitted changes. Use 'git stash' first."
        ),
        (
            r"git\s+reset\s+--merge",
            "git reset --merge can lose uncommitted changes."
        ),
        # Git clean
        (
            r"git\s+clean\s+-[a-z]*f",
            "git clean -f removes untracked files permanently. Review with 'git clean -n' first."
        ),
        # Force operations
        (
            r"git\s+push\s+.*--force(?![-a-z])",
            "Force push can destroy remote history. Use --force-with-lease if necessary."
        ),
        (
            r"git\s+push\s+.*-f\b",
            "Force push (-f) can destroy remote history. Use --force-with-lease if necessary."
        ),
        (
            r"git\s+branch\s+-D\b",
            "git branch -D force-deletes without merge check. Use -d for safety."
        ),
        # Destructive filesystem commands
        (
            r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+[/~]|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+[/~]",
            "rm -rf on root or home paths is EXTREMELY DANGEROUS. This command will NOT be executed. Ask the user to run it manually if truly needed."
        ),
        (
            r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f|rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR]",
            "rm -rf is destructive and requires human approval. Explain what you want to delete and why, then ask the user to run the command manually."
        ),
        (
            r"rm\s+(-[a-zA-Z]+\s+)*-[rR]\s+(-[a-zA-Z]+\s+)*-f|rm\s+(-[a-zA-Z]+\s+)*-f\s+(-[a-zA-Z]+\s+)*-[rR]",
            "rm with separate -r -f flags is destructive and requires human approval."
        ),
        (
            r"rm\s+.*--recursive.*--force|rm\s+.*--force.*--recursive",
            "rm --recursive --force is destructive and requires human approval."
        ),
        # Git stash drop/clear without explicit permission
        (
            r"git\s+stash\s+drop",
            "git stash drop permanently deletes stashed changes. List stashes first."
        ),
        (
            r"git\s+stash\s+clear",
            "git stash clear permanently deletes ALL stashed changes."
        ),
    ]

    # Patterns that are safe even if they match above (allowlist)
    SAFE_PATTERNS = [
        r"git\s+checkout\s+-b\s+",           # Creating new branch
        r"git\s+checkout\s+--orphan\s+",     # Creating orphan branch
        r"git\s+restore\s+--staged\s+(?!.*--worktree)(?!.*-W\b)",  # Unstaging only (safe)
        r"git\s+restore\s+-S\s+(?!.*--worktree)(?!.*-W\b)",        # Unstaging short form (safe)
        r"git\s+clean\s+-[a-z]*n[a-z]*",     # Dry run (matches -n, -fn, -nf, -xnf, etc.)
        r"git\s+clean\s+--dry-run",          # Dry run (long form)
        # Allow rm -rf on temp directories
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+/tmp/",
        r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+/tmp/",
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+/var/tmp/",
        r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+/var/tmp/",
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+\$TMPDIR/",
        r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+\$TMPDIR/",
        r"rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+\$\{TMPDIR",
        r"rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+\$\{TMPDIR",
        r'rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+"\$TMPDIR/',
        r'rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+"\$TMPDIR/',
        r'rm\s+-[a-zA-Z]*[rR][a-zA-Z]*f[a-zA-Z]*\s+"\$\{TMPDIR',
        r'rm\s+-[a-zA-Z]*f[a-zA-Z]*[rR][a-zA-Z]*\s+"\$\{TMPDIR',
        r"rm\s+(-[a-zA-Z]+\s+)*-[rR]\s+(-[a-zA-Z]+\s+)*-f\s+/tmp/",
        r"rm\s+(-[a-zA-Z]+\s+)*-f\s+(-[a-zA-Z]+\s+)*-[rR]\s+/tmp/",
        r"rm\s+(-[a-zA-Z]+\s+)*-[rR]\s+(-[a-zA-Z]+\s+)*-f\s+/var/tmp/",
        r"rm\s+(-[a-zA-Z]+\s+)*-f\s+(-[a-zA-Z]+\s+)*-[rR]\s+/var/tmp/",
        r"rm\s+.*--recursive.*--force\s+/tmp/",
        r"rm\s+.*--force.*--recursive\s+/tmp/",
        r"rm\s+.*--recursive.*--force\s+/var/tmp/",
        r"rm\s+.*--force.*--recursive\s+/var/tmp/",
    ]


    def _normalize_absolute_paths(cmd):
        """Normalize absolute paths to rm/git for consistent pattern matching."""
        if not cmd:
            return cmd

        result = cmd
        result = re.sub(r'^/(?:\S*/)*s?bin/rm(?=\s|$)', 'rm', result)
        result = re.sub(r'^/(?:\S*/)*s?bin/git(?=\s|$)', 'git', result)
        return result


    def main():
        try:
            input_data = json.load(sys.stdin)
        except json.JSONDecodeError:
            sys.exit(0)

        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input") or {}
        command = tool_input.get("command", "")

        if tool_name != "Bash" or not isinstance(command, str) or not command:
            sys.exit(0)

        original_command = command
        command = _normalize_absolute_paths(command)

        for pattern in SAFE_PATTERNS:
            if re.search(pattern, command):
                sys.exit(0)

        for pattern, reason in DESTRUCTIVE_PATTERNS:
            if re.search(pattern, command):
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": (
                            f"BLOCKED by git_safety_guard.py\n\n"
                            f"Reason: {reason}\n\n"
                            f"Command: {original_command}\n\n"
                            f"If this operation is truly needed, ask the user for explicit "
                            f"permission and have them run the command manually."
                        )
                    }
                }
                print(json.dumps(output))
                sys.exit(0)

        sys.exit(0)


    if __name__ == "__main__":
        main()
  '';

  # Settings as Nix attrset
  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    model = "opus";
    enabledPlugins = {
      "hookify@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;
    };
    statusLine = {
      type = "command";
      command = "${claude-statusline}/bin/claude-statusline";
    };
    hooks = {
      PreToolUse = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "${claude-sleep-inhibit}/bin/claude-sleep-inhibit start";
            }
          ];
        }
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${git-safety-guard}/bin/git-safety-guard";
            }
          ];
        }
      ];
      Notification = [
        {
          matcher = "permission_prompt";
          hooks = [
            {
              type = "command";
              command = "${claude-alert}/bin/claude-alert";
            }
          ];
        }
      ];
      PostToolUse = [
        {
          matcher = "AskUserQuestion";
          hooks = [
            {
              type = "command";
              command = "${claude-alert}/bin/claude-alert";
            }
          ];
        }
      ];
      Stop = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "${claude-sleep-inhibit}/bin/claude-sleep-inhibit stop";
            }
          ];
        }
      ];
    };
    permissions = {
      deny = [
        "Bash(rm -rf /)"
        "Bash(rm -rf /*)"
        "Bash(rm -rf ~)"
        "Bash(rm -rf $HOME)"
        "Bash(rm -rf ~/*)"
        "Bash(rm -rf $HOME/*)"
        "Bash(mkfs:*)"
        "Bash(dd if=/dev/zero:*)"
        "Bash(dd if=/dev/urandom:*)"
        "Bash(dd of=/dev/sd:*)"
        "Bash(dd of=/dev/nvme:*)"
        "Bash(chmod -R 777 /)"
        "Bash(chmod -R 777 /*)"
        "Bash(git push --force origin main)"
        "Bash(git push --force origin master)"
        "Bash(git push -f origin main)"
        "Bash(git push -f origin master)"
      ];
      allow = [
        "Bash(git:*)"
        "Bash(gh:*)"
        "Bash(nix search:*)"
        "Bash(nix show:*)"
        "Bash(nix build:*)"
        "Bash(nix develop:*)"
        "Bash(nix shell:*)"
        "Bash(nix run:*)"
        "Bash(nix flake:*)"
        "Bash(nix eval:*)"
        "Bash(nix repl:*)"
        "Bash(nix why-depends:*)"
        "Bash(nix path-info:*)"
        "Bash(nix derivation show:*)"
        "Bash(nix hash:*)"
        "Bash(nix log:*)"
        "Bash(nix copy:*)"
        "Bash(nix profile list:*)"
        "Bash(nix profile history:*)"
        "Bash(nix-build:*)"
        "Bash(nix-shell:*)"
        "Bash(nix-prefetch-url:*)"
        "Bash(nix-prefetch-git:*)"
        "Bash(nix-instantiate:*)"
        "Bash(nix-store --query:*)"
        "Bash(nix-store -q:*)"
        "Bash(nix-env -q:*)"
        "Bash(nix-env --query:*)"
        "Bash(nix-channel --list:*)"
        "Bash(nh os build:*)"
        "Bash(nh os test:*)"
        "Bash(nh os boot:*)"
        "Bash(nh home:*)"
        "Bash(nh search:*)"
        "Bash(curl:*)"
        "Bash(wget:*)"
        "Bash(ls:*)"
        "Bash(cat:*)"
        "Bash(head:*)"
        "Bash(tail:*)"
        "Bash(find:*)"
        "Bash(fd:*)"
        "Bash(file:*)"
        "Bash(readlink:*)"
        "Bash(realpath:*)"
        "Bash(tar:*)"
        "Bash(unzip:*)"
        "Bash(gzip:*)"
        "Bash(gunzip:*)"
        "Bash(timeout:*)"
        "Bash(mkdir:*)"
        "Bash(cp:*)"
        "Bash(mv:*)"
        "Bash(rm:*)"
        "Bash(grep:*)"
        "Bash(rg:*)"
        "Bash(ag:*)"
        "Bash(sed:*)"
        "Bash(awk:*)"
        "Bash(jq:*)"
        "Bash(yq:*)"
        "Bash(which:*)"
        "Bash(whereis:*)"
        "Bash(type:*)"
        "Bash(echo:*)"
        "Bash(printf:*)"
        "Bash(pwd)"
        "Bash(env)"
        "Bash(printenv:*)"
        "Bash(date:*)"
        "Bash(wc:*)"
        "Bash(sort:*)"
        "Bash(uniq:*)"
        "Bash(cut:*)"
        "Bash(tr:*)"
        "Bash(diff:*)"
        "Bash(comm:*)"
        "Bash(tee:*)"
        "Bash(xargs:*)"
        "Bash(bd:*)"
        "Bash(npm:*)"
        "Bash(npx:*)"
        "Bash(pnpm:*)"
        "Bash(yarn:*)"
        "Bash(bun:*)"
        "Bash(node:*)"
        "Bash(deno:*)"
        "Bash(tsc:*)"
        "Bash(tsx:*)"
        "Bash(python:*)"
        "Bash(python3:*)"
        "Bash(pip:*)"
        "Bash(pip3:*)"
        "Bash(cargo:*)"
        "Bash(rustc:*)"
        "Bash(go:*)"
        "Bash(make:*)"
        "Bash(cmake:*)"
        "Bash(just:*)"
        "Bash(docker:*)"
        "Bash(docker-compose:*)"
        "Bash(kubectl:*)"
        "Bash(terraform:*)"
        "Bash(ldd:*)"
        "Bash(nm:*)"
        "Bash(objdump:*)"
        "Bash(strings:*)"
        "Bash(stat:*)"
        "Bash(du:*)"
        "Bash(df:*)"
        "Bash(tree:*)"
        "Bash(bat:*)"
        "Bash(less:*)"
        "Bash(man:*)"
        "WebSearch"
        "WebFetch(domain:*)"
        "Read(//nix/store/**)"
        "Read(**)"
      ];
    };
  };
in {
  home.file.".claude/CLAUDE.md".source = ./global-memory.md;

  home.file.".claude/commands" = {
    source = ./commands;
    recursive = true;
  };

  home.file.".claude/skills" = {
    source = ./skills;
    recursive = true;
  };

  home.file.".claude/agents" = {
    source = ./agents;
    recursive = true;
  };

  home.file.".claude/settings.json".text = builtins.toJSON settings;
}
