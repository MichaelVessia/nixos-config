{pkgs, ...}: let
  direnvPackage =
    if pkgs.stdenv.hostPlatform.isDarwin
    then
      pkgs.direnv.overrideAttrs (_: {
        # nixpkgs' Fish check is currently killed on Darwin for direnv 2.37.1.
        checkPhase = ''
          runHook preCheck
          make test-go test-bash test-zsh
          runHook postCheck
        '';
      })
    else pkgs.direnv;
in {
  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    # custom settings
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      # line_break.disabled = true;  # causes line-wrap issues with long prompts
      package.disabled = true;
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    initContent = ''
      export PATH="/opt/homebrew/bin:$PATH:$HOME/bin:$HOME/.local/bin:$HOME/.bun/bin"
      export NH_FLAKE="$HOME/nixos-config"
      export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

      # fzf settings - use fd for faster file search
      export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

      # sops-nix secrets (platform-aware: NixOS uses /run/secrets/, macOS uses ~/.config/sops-nix/secrets/)
      SECRETS_DIR="/run/secrets"
      [ -d "$HOME/.config/sops-nix/secrets" ] && SECRETS_DIR="$HOME/.config/sops-nix/secrets"

      [ -f "$SECRETS_DIR/paperless_url" ] && export PAPERLESS_URL="$(cat "$SECRETS_DIR/paperless_url")"
      [ -f "$SECRETS_DIR/paperless_token" ] && export PAPERLESS_TOKEN="$(cat "$SECRETS_DIR/paperless_token")"
      [ -f "$SECRETS_DIR/x_to_obsidian_vault_path" ] && export X_TO_OBSIDIAN_VAULT_PATH="$(cat "$SECRETS_DIR/x_to_obsidian_vault_path")"
      [ -f "$SECRETS_DIR/x_to_obsidian_llm_provider" ] && export X_TO_OBSIDIAN_LLM_PROVIDER="$(cat "$SECRETS_DIR/x_to_obsidian_llm_provider")"
      [ -f "$SECRETS_DIR/x_to_obsidian_google_api_key" ] && export X_TO_OBSIDIAN_GOOGLE_API_KEY="$(cat "$SECRETS_DIR/x_to_obsidian_google_api_key")"
      [ -f "$SECRETS_DIR/fmcal_username" ] && export FMCAL_USERNAME="$(cat "$SECRETS_DIR/fmcal_username")"
      [ -f "$SECRETS_DIR/fmcal_password" ] && export FMCAL_PASSWORD="$(cat "$SECRETS_DIR/fmcal_password")"
      [ -f "$SECRETS_DIR/hass_server" ] && export HASS_SERVER="$(cat "$SECRETS_DIR/hass_server")"
      [ -f "$SECRETS_DIR/hass_token" ] && export HASS_TOKEN="$(cat "$SECRETS_DIR/hass_token")"
      [ -f "$SECRETS_DIR/freshrss_api_user" ] && export FRESHRSS_API_USER="$(cat "$SECRETS_DIR/freshrss_api_user")"
      [ -f "$SECRETS_DIR/freshrss_api_password" ] && export FRESHRSS_API_PASSWORD="$(cat "$SECRETS_DIR/freshrss_api_password")"
      [ -f "$SECRETS_DIR/freshrss_url" ] && export FRESHRSS_URL="$(cat "$SECRETS_DIR/freshrss_url")"
      [ -f "$SECRETS_DIR/kuma_url" ] && export KUMA_URL="$(cat "$SECRETS_DIR/kuma_url")"
      [ -f "$SECRETS_DIR/kuma_username" ] && export KUMA_USERNAME="$(cat "$SECRETS_DIR/kuma_username")"
      [ -f "$SECRETS_DIR/kuma_password" ] && export KUMA_PASSWORD="$(cat "$SECRETS_DIR/kuma_password")"
      [ -f "$SECRETS_DIR/sonarr_url" ] && export SONARR_URL="$(cat "$SECRETS_DIR/sonarr_url")"
      [ -f "$SECRETS_DIR/sonarr_api_key" ] && export SONARR_API_KEY="$(cat "$SECRETS_DIR/sonarr_api_key")"
      [ -f "$SECRETS_DIR/radarr_url" ] && export RADARR_URL="$(cat "$SECRETS_DIR/radarr_url")"
      [ -f "$SECRETS_DIR/radarr_api_key" ] && export RADARR_API_KEY="$(cat "$SECRETS_DIR/radarr_api_key")"
      [ -f "$SECRETS_DIR/prowlarr_url" ] && export PROWLARR_URL="$(cat "$SECRETS_DIR/prowlarr_url")"
      [ -f "$SECRETS_DIR/prowlarr_api_key" ] && export PROWLARR_API_KEY="$(cat "$SECRETS_DIR/prowlarr_api_key")"
      [ -f "$SECRETS_DIR/sabnzbd_url" ] && export SABNZBD_URL="$(cat "$SECRETS_DIR/sabnzbd_url")"
      [ -f "$SECRETS_DIR/sabnzbd_api_key" ] && export SABNZBD_API_KEY="$(cat "$SECRETS_DIR/sabnzbd_api_key")"
      [ -f "$SECRETS_DIR/jellyseerr_url" ] && export JELLYSEERR_URL="$(cat "$SECRETS_DIR/jellyseerr_url")"
      [ -f "$SECRETS_DIR/jellyseerr_api_key" ] && export JELLYSEERR_API_KEY="$(cat "$SECRETS_DIR/jellyseerr_api_key")"
      [ -f "$SECRETS_DIR/caddy_url" ] && export CADDY_URL="$(cat "$SECRETS_DIR/caddy_url")"
      [ -f "$SECRETS_DIR/jellyfin_url" ] && export JELLYFIN_URL="$(cat "$SECRETS_DIR/jellyfin_url")"
      [ -f "$SECRETS_DIR/jellyfin_api_key" ] && export JELLYFIN_API_KEY="$(cat "$SECRETS_DIR/jellyfin_api_key")"
      [ -f "$SECRETS_DIR/autocaliweb_url" ] && export AUTOCALIWEB_URL="$(cat "$SECRETS_DIR/autocaliweb_url")"
      [ -f "$SECRETS_DIR/autocaliweb_username" ] && export AUTOCALIWEB_USERNAME="$(cat "$SECRETS_DIR/autocaliweb_username")"
      [ -f "$SECRETS_DIR/autocaliweb_password" ] && export AUTOCALIWEB_PASSWORD="$(cat "$SECRETS_DIR/autocaliweb_password")"
      export AUTOCALIWEB_PROXMOX_HOST="proxmox"
      export AUTOCALIWEB_CTID="101"
      export AUTOCALIWEB_INGEST_DIR="/book-ingest"
      [ -n "$AUTOCALIWEB_URL" ] || export AUTOCALIWEB_URL="http://192.168.1.145:8083"
      [ -f "$SECRETS_DIR/tubearchivist_url" ] && export TUBEARCHIVIST_URL="$(cat "$SECRETS_DIR/tubearchivist_url")"
      [ -f "$SECRETS_DIR/tubearchivist_username" ] && export TUBEARCHIVIST_USERNAME="$(cat "$SECRETS_DIR/tubearchivist_username")"
      [ -f "$SECRETS_DIR/tubearchivist_password" ] && export TUBEARCHIVIST_PASSWORD="$(cat "$SECRETS_DIR/tubearchivist_password")"
      [ -f "$SECRETS_DIR/adguard_url" ] && export ADGUARD_URL="$(cat "$SECRETS_DIR/adguard_url")"
      [ -f "$SECRETS_DIR/adguard_username" ] && export ADGUARD_USERNAME="$(cat "$SECRETS_DIR/adguard_username")"
      [ -f "$SECRETS_DIR/adguard_password" ] && export ADGUARD_PASSWORD="$(cat "$SECRETS_DIR/adguard_password")"
      [ -f "$SECRETS_DIR/immich_url" ] && export IMMICH_URL="$(cat "$SECRETS_DIR/immich_url")"
      [ -f "$SECRETS_DIR/immich_api_key" ] && export IMMICH_API_KEY="$(cat "$SECRETS_DIR/immich_api_key")"
      [ -f "$SECRETS_DIR/flocasts_npm_token" ] && export FLOCASTS_NPM_TOKEN="$(cat "$SECRETS_DIR/flocasts_npm_token")"
      [ -f "$SECRETS_DIR/github_token" ] && export GITHUB_TOKEN="$(cat "$SECRETS_DIR/github_token")"
      [ -f "$SECRETS_DIR/jira_api_token" ] && export JIRA_API_TOKEN="$(cat "$SECRETS_DIR/jira_api_token")"
      [ -f "$SECRETS_DIR/dd_app_key" ] && export DD_APP_KEY="$(cat "$SECRETS_DIR/dd_app_key")"
      [ -f "$SECRETS_DIR/dd_api_key" ] && export DD_API_KEY="$(cat "$SECRETS_DIR/dd_api_key")"

      # AI agent telemetry -> Datadog (shared key for Claude Code + Codex + opencode)
      if [ -f "$SECRETS_DIR/dd_telemetry_api_key" ]; then
        export DD_TELEMETRY_API_KEY="$(cat "$SECRETS_DIR/dd_telemetry_api_key")"
        # opencode only enables OTEL when the generic base endpoint is set.
        export OTEL_EXPORTER_OTLP_ENDPOINT="https://otlp.datadoghq.com"
        export OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
        # Claude Code OTEL
        export CLAUDE_CODE_ENABLE_TELEMETRY=1
        export OTEL_LOGS_EXPORTER=otlp
        export OTEL_EXPORTER_OTLP_LOGS_PROTOCOL="http/protobuf"
        export OTEL_EXPORTER_OTLP_LOGS_ENDPOINT="https://http-intake.logs.datadoghq.com/v1/logs"
        export OTEL_EXPORTER_OTLP_HEADERS="dd-api-key=$DD_TELEMETRY_API_KEY"
        export OTEL_METRICS_EXPORTER=otlp
        export OTEL_EXPORTER_OTLP_METRICS_PROTOCOL="http/protobuf"
        export OTEL_EXPORTER_OTLP_METRICS_ENDPOINT="https://otlp.datadoghq.com/v1/metrics"
        # Trace-specific OTLP vars for tools that honor per-signal endpoints
        export OTEL_TRACES_EXPORTER=otlp
        export OTEL_EXPORTER_OTLP_TRACES_PROTOCOL="http/protobuf"
        export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="https://otlp.datadoghq.com/v1/traces"
      fi

      [ -f "$SECRETS_DIR/rootly_api_key" ] && export ROOTLY_API_KEY="$(cat "$SECRETS_DIR/rootly_api_key")"

    '';

    shellAliases = {
      vim = "nvim";

      # AI tools
      c = "claude";
      cr = "claude --resume";
      cy = "claude --dangerously-skip-permissions";
      cry = "claude --resume --dangerously-skip-permissions";
      co = "codex";
      coy = "codex --yolo";
      cory = "codex --resume --yolo";
      oc = "opencode";

      # eza aliases (ls replacement)
      ls = "eza";
      ll = "eza -l";
      la = "eza -la";
      lt = "eza --tree";

      # zoxide aliases (cd replacement)
      cd = "z";
      cdls = "zoxide query --list | fzf --header 'Choose directory'";

      # bat aliases (cat replacement)
      cat = "bat";

      # Verbosity and qol
      cp = "cp -v";
      ddf = "df -h";
      etc = "erd -H";
      mkdir = "mkdir -p";
      mv = "mv -v";
      rm = "rm -v";

      # Git aliases
      gaa = "git add -A";
      ga = "git add";
      gbd = "git branch --delete";
      gb = "git branch";
      gc = "git commit";
      gcm = "git commit -m";
      gcob = "git checkout -b";
      gco = "git checkout";
      gd = "git diff";
      gl = "git log";
      gp = "git push";
      gph = "git push -u origin HEAD";
      gs = "git status";
      gst = "git stash";
      gstp = "git stash pop";

      # NH (nix helper) aliases - platform-aware
      # NixOS
      nrs = "nh os switch"; # rebuild and switch (NixOS)
      nrt = "nh os test"; # test build (reverts on reboot)
      nrb = "nh os boot"; # build, activate on next boot
      ngen = "nh os generations"; # list generations
      nroll = "nh os rollback"; # rollback to previous
      # macOS (nix-darwin)
      nds = "nh darwin switch"; # rebuild and switch (darwin)
      # Cross-platform
      nrc = "nh clean all"; # garbage collect
      nsearch = "nh search"; # search packages

      # zellij aliases
      zls = "zellij list-sessions"; # list sessions
      zn = "zellij --session"; # new session (usage: zn myname)
      za = "zellij attach"; # attach to session
      zk = "zellij kill-session"; # kill session
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      NIXOS_CONFIG = "$HOME/nixos-config";
      TMPDIR = "$HOME/.cache/tmp";
      NH_FLAKE = "$HOME/nixos-config"; # for nh on all platforms
    };
  };

  # atuin - magical shell history
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      search_mode = "fuzzy";
    };
  };

  # zoxide - smarter cd command
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # fzf - fuzzy finder
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # eza - modern ls replacement
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };

  # bat - cat replacement with syntax highlighting
  programs.bat = {
    enable = true;
  };

  # direnv - load/unload environment based on directory
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    package = direnvPackage;
    nix-direnv.enable = true;
  };
}
