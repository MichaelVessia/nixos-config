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
      input=$(cat)

      cwd=$(echo "$input" | jq -r '.workspace.current_dir')
      model=$(echo "$input" | jq -r '.model.display_name')
      output_style=$(echo "$input" | jq -r '.output_style.name // "default"')
      current_dir=$(basename "$cwd")

      # Git: green  for clean, yellow  for dirty
      git_info=""
      if git -C "$cwd" --no-optional-locks rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git -C "$cwd" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ -n $(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null) ]]; then
          git_info=$(printf "\033[33m  %s\033[0m" "$branch")
        else
          git_info=$(printf "\033[32m  %s\033[0m" "$branch")
        fi
      fi

      # Context: green < 50%, yellow < 75%, red >= 75%
      context_info=""
      usage=$(echo "$input" | jq '.context_window.current_usage')
      if [ "$usage" != "null" ]; then
        current=$(echo "$usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
        size=$(echo "$input" | jq '.context_window.context_window_size')
        pct=$((current * 100 / size))
        if [ "$pct" -lt 50 ]; then
          color="\033[32m"
        elif [ "$pct" -lt 75 ]; then
          color="\033[33m"
        else
          color="\033[31m"
        fi
        context_info=$(printf " \033[2m|\033[0m ''${color}%d%%\033[0m ctx" "$pct")
      fi

      hostname=$(hostname -s)

      # Output style (only if not default)
      style_info=""
      if [ "$output_style" != "default" ]; then
        style_info=$(printf " \033[2m|\033[0m \033[36m%s\033[0m" "$output_style")
      fi

      printf "\033[32m%s\033[0m@\033[34m%s\033[0m in \033[36m%s\033[0m%s \033[2m|\033[0m \033[35m%s\033[0m%s%s" \
        "$USER" "$hostname" "$current_dir" "''${git_info:+ $git_info}" "$model" "$style_info" "$context_info"
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

  sharedInstructions = builtins.readFile ../shared/instructions.md;

  # Settings as Nix attrset
  settings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    theme = "auto";
    model = "opus";
    effortLevel = "high";
    attribution = {
      commit = "";
      pr = "";
    };
    teammateMode = "in-process";
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
    skipDangerousModePermissionPrompt = true;
    enabledPlugins = {
      "codex@openai-codex" = true;
    };
    extraKnownMarketplaces = {
      openai-codex = {
        source = {
          source = "github";
          repo = "openai/codex-plugin-cc";
        };
      };
    };
    statusLine = {
      type = "command";
      command = "claude-statusline";
    };
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "dcg";
            }
          ];
        }
        {
          matcher = "AskUserQuestion";
          hooks = [
            {
              type = "command";
              command = "claude-alert";
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
              command = "claude-alert";
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

  claudeSettingsFile = pkgs.writeText "claude-settings.json" (builtins.toJSON settings);
in {
  config = {
    home.file = {
      ".claude/CLAUDE.md".text = sharedInstructions;
      ".claude/agents" = {
        source = ./agents;
        recursive = true;
      };
    };

    # Copy Claude config as a regular file (not symlink)
    home.activation.claudeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      rm -f "$HOME/.claude/settings.json"
      install -Dm644 ${claudeSettingsFile} "$HOME/.claude/settings.json"
    '';

    # Claude helper binaries + dcg in PATH for hooks and manual use
    home.packages = [
      claude-statusline
      claude-alert
      dcg
      pkgs.nodejs
    ];

    # dcg config
    xdg.configFile."dcg/config.toml".source = (pkgs.formats.toml {}).generate "dcg-config.toml" dcgConfig;
  };
}
