{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  # Wrapped scripts with explicit deps
  claude-statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [pkgs.jq pkgs.git pkgs.coreutils];
    text = ''
      input=$(cat)

      model_name=$(echo "$input" | jq -r '.model.id // "unknown"')
      cwd=$(echo "$input" | jq -r '.workspace.current_dir')

      # Context usage
      context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
      usage=$(echo "$input" | jq '.context_window.current_usage')
      if [ "$usage" != "null" ] && [ "$context_size" -gt 0 ] 2>/dev/null; then
        current_tokens=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
        if [ "$current_tokens" != "null" ] && [ "$current_tokens" -ge 0 ] 2>/dev/null; then
          context_pct=$((current_tokens * 100 / context_size))
        else
          context_pct="-"
        fi
      else
        context_pct="-"
      fi

      branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
      dir_name=$(basename "$cwd")
      user_host="$(whoami)@$(hostname -s)"

      # Shorten model name (e.g., "claude-opus-4-6-20250929" -> "Opus 4.6")
      short_model=$(echo "$model_name" | sed 's/^claude-//' | sed 's/-[0-9]\{8\}$//')
      # Capitalize and dot-separate version: "opus-4-6" -> "Opus 4.6"
      short_model=$(echo "$short_model" | sed 's/^\(.\)/\U\1/' | sed 's/-\([0-9]\)/.\1/g' | sed 's/\./ /' )

      # Colors
      C_CYAN="\033[36m"
      C_WHITE="\033[37m"
      C_MAGENTA="\033[35m"
      C_RED="\033[31m"
      C_GREEN="\033[32m"
      C_RESET="\033[0m"

      # Format context
      if [ "$context_pct" = "-" ]; then
        ctx_display="-"
      else
        ctx_display="''${context_pct}% ctx"
      fi

      # Build: user@host in project    branch | Model | N% ctx
      line="''${C_CYAN}''${user_host}''${C_WHITE} in ''${C_MAGENTA}''${dir_name}"
      if [ -n "$branch" ]; then
        line="''${line}    ''${C_RED}''${branch}"
      fi
      line="''${line} ''${C_WHITE}| ''${C_WHITE}''${short_model} ''${C_WHITE}| ''${C_GREEN}''${ctx_display}''${C_RESET}"

      printf "%b\n" "$line"
    '';
  };

  alertSound = ./sounds/teleport.ogg;

  claude-alert = pkgs.writeShellApplication {
    name = "claude-alert";
    runtimeInputs =
      lib.optionals pkgs.stdenv.isLinux [pkgs.pipewire]
      ++ lib.optionals pkgs.stdenv.isDarwin [pkgs.ffmpeg];
    text = ''
      if [[ "$(uname -s)" == "Darwin" ]]; then
        ffplay -nodisp -autoexit -loglevel quiet ${alertSound} 2>/dev/null &
      else
        pw-play ${alertSound} 2>/dev/null &
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
      [pkgs.coreutils pkgs.util-linux]
      ++ lib.optionals pkgs.stdenv.isLinux [pkgs.systemd pkgs.procps];
    text = ''
      PIDFILE="/tmp/claude-sleep-inhibit.pid"
      LOCKFILE="/tmp/claude-sleep-inhibit.lock"
      LOCKNAME="Claude Code session"
      OS="$(uname -s)"

      start_linux() {
        (
          flock 9
          if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            exit 0
          fi
          # Pidfile stale or missing, clean up any orphaned inhibitors
          pkill -f "systemd-inhibit.*--who=claude-code" 2>/dev/null || true
          rm -f "$PIDFILE"
          systemd-inhibit --what=sleep:idle --who="claude-code" --why="$LOCKNAME" sleep infinity </dev/null >/dev/null 2>&1 &
          echo $! > "$PIDFILE"
        ) 9>"$LOCKFILE"
      }

      start_darwin() {
        osascript -e 'tell application "Amphetamine" to start new session' >/dev/null 2>&1
      }

      stop_linux() {
        (
          flock 9
          if [ -f "$PIDFILE" ]; then
            pid=$(cat "$PIDFILE")
            kill "$pid" 2>/dev/null || true
            rm -f "$PIDFILE"
          fi
        ) 9>"$LOCKFILE"
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

  # Destructive Command Guard - blocks dangerous commands for AI agents
  # https://github.com/Dicklesworthstone/destructive_command_guard
  dcg = let
    version = "0.2.15";
    platform =
      {
        x86_64-linux = {
          target = "x86_64-unknown-linux-gnu";
          sha256 = "9995596fddc65d686875fc04a8d2c47d0dd4b21b42e33d7dbd3c5d2d2dd9bb6a";
        };
        aarch64-linux = {
          target = "aarch64-unknown-linux-gnu";
          sha256 = "da71dfe727fc0390df32d36c3766b78b658606c87de888cde1aea72eea17d2d4";
        };
        x86_64-darwin = {
          target = "x86_64-apple-darwin";
          sha256 = "808b76b49497757a0614ac8bf6a1aeb792c575dfaa691a8e8852305cca8d1ff0";
        };
        aarch64-darwin = {
          target = "aarch64-apple-darwin";
          sha256 = "e205a9090dd0defa5b93af4e0c9f555623da760b07da30b6aa4619056922251e";
        };
      }
      .${
        pkgs.stdenv.hostPlatform.system
      };
  in
    pkgs.stdenv.mkDerivation {
      pname = "destructive-command-guard";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://github.com/Dicklesworthstone/destructive_command_guard/releases/download/v${version}/dcg-${platform.target}.tar.xz";
        sha256 = platform.sha256;
      };

      nativeBuildInputs = [pkgs.xz];

      unpackPhase = ''
        tar -xf $src
      '';

      installPhase = ''
        mkdir -p $out/bin
        cp dcg $out/bin/
        chmod +x $out/bin/dcg
      '';

      meta = {
        description = "High-performance hook for AI agents that blocks destructive commands";
        homepage = "https://github.com/Dicklesworthstone/destructive_command_guard";
        platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      };
    };

  # dcg config as Nix attrset
  dcgConfig = {
    packs = {
      enabled = [
        # Core
        "core.git"
        "strict_git"
        "core.filesystem"
        # Cloud & CDN
        "cloud.aws"
        "storage.s3"
        "dns.cloudflare"
        "apigateway.aws"
        # Containers & Orchestration
        "containers.docker"
        "kubernetes.kubectl"
        "kubernetes.helm"
        # Databases
        "database.postgresql"
        "database.redis"
        "database.sqlite"
        # Infrastructure
        "infrastructure.terraform"
        # CI/CD
        "cicd.github_actions"
        # Monitoring
        "monitoring.datadog"
        # Messaging
        "messaging.sqs_sns"
        # Search
        "search.opensearch"
        # Remote Access
        "remote.ssh"
        "remote.scp"
        # Payments
        "payment.stripe"
        # Feature Flags
        "featureflags.launchdarkly"
      ];
    };
    agents = {
      claude-code = {
        trust_level = "medium";
      };
    };
  };

  # Agent instructions: shared base + Claude-specific overlay
  sharedInstructions = builtins.readFile ./shared-instructions.md;
  claudeOverlay = builtins.readFile ./claude-overlay.md;

  # Settings as Nix attrset
  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    model = "opus";
    attribution = {
      commit = "";
      pr = "";
    };
    enabledPlugins = {
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
              command = "${dcg}/bin/dcg";
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

  codexConfig = {
    personality = "pragmatic";
    model = "gpt-5.3-codex";
    model_reasoning_effort = "high";
    status_line = ["model" "context-remaining" "git-branch"];
    mcp_servers = {
      atlassian = {
        url = "https://mcp.atlassian.com/v1/mcp";
      };
    };
    otel = {
      environment = "dev";
      log_user_prompt = false;
      exporter = {
        otlp-http = {
          endpoint = "https://http-intake.logs.datadoghq.com/v1/logs";
          protocol = "binary";
          headers = {
            "dd-api-key" = "$" + "{DD_TELEMETRY_API_KEY}";
          };
        };
      };
      trace_exporter = {
        otlp-http = {
          endpoint = "https://otlp.datadoghq.com/v1/traces";
          protocol = "binary";
          headers = {
            "dd-api-key" = "$" + "{DD_TELEMETRY_API_KEY}";
          };
        };
      };
    };
  };
in {
  imports = [inputs.agent-skills-nix.homeManagerModules.default];

  programs.agent-skills = {
    enable = true;
    sources =
      {
        personal.path = ./skills;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        flocasts = {
          path = inputs.flocasts-skills;
          subdir = "skills";
        };
      };
    skills.enableAll = true;
    targets = {
      claude = {
        dest = "$HOME/.agents/skills";
        structure = "symlink-tree";
      };
      codex = {
        enable = true;
        dest = "$HOME/.agents/skills";
        structure = "symlink-tree";
      };
      opencode = {
        enable = true;
        dest = "$HOME/.agents/skills";
        structure = "symlink-tree";
      };
    };
  };

  home.file = {
    ".claude/CLAUDE.md".text = claudeOverlay + "\n" + sharedInstructions;
    ".codex/AGENTS.md".text = sharedInstructions;
    ".codex/config.toml".source = (pkgs.formats.toml {}).generate "codex-config.toml" codexConfig;
    ".config/opencode/AGENTS.md".text = sharedInstructions;
    ".claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
    ".codex/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
    ".config/opencode/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/skills";
    ".claude/memory" = {
      source = ./memory;
      recursive = true;
    };
    ".claude/agents" = {
      source = ./agents;
      recursive = true;
    };
    ".claude/settings.json".text = builtins.toJSON settings;
  };

  # dcg (destructive command guard) in PATH for manual use
  home.packages = [dcg];

  # dcg config
  xdg.configFile."dcg/config.toml".source = (pkgs.formats.toml {}).generate "dcg-config.toml" dcgConfig;
}
