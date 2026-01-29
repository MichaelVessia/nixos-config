{
  config,
  pkgs,
  ...
}: {
  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    # custom settings
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
      package.disabled = true;
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO add your custom bashrc here
    bashrcExtra = ''
      export PATH="/opt/homebrew/bin:$PATH:$HOME/bin:$HOME/.local/bin:$HOME/.bun/bin"
      export NH_FLAKE="$HOME/nixos-config"
      export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"

      # fzf settings - use fd for faster file search
      export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
      export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

      # sops-nix secrets (NixOS only)
      [ -f /run/secrets/paperless_url ] && export PAPERLESS_URL="$(cat /run/secrets/paperless_url)"
      [ -f /run/secrets/paperless_token ] && export PAPERLESS_TOKEN="$(cat /run/secrets/paperless_token)"
      [ -f /run/secrets/x_to_obsidian_vault_path ] && export X_TO_OBSIDIAN_VAULT_PATH="$(cat /run/secrets/x_to_obsidian_vault_path)"
      [ -f /run/secrets/x_to_obsidian_llm_provider ] && export X_TO_OBSIDIAN_LLM_PROVIDER="$(cat /run/secrets/x_to_obsidian_llm_provider)"
      [ -f /run/secrets/x_to_obsidian_google_api_key ] && export X_TO_OBSIDIAN_GOOGLE_API_KEY="$(cat /run/secrets/x_to_obsidian_google_api_key)"
      [ -f /run/secrets/fmcal_username ] && export FMCAL_USERNAME="$(cat /run/secrets/fmcal_username)"
      [ -f /run/secrets/fmcal_password ] && export FMCAL_PASSWORD="$(cat /run/secrets/fmcal_password)"
      [ -f /run/secrets/hass_server ] && export HASS_SERVER="$(cat /run/secrets/hass_server)"
      [ -f /run/secrets/hass_token ] && export HASS_TOKEN="$(cat /run/secrets/hass_token)"
    '';

    # set some aliases, feel free to add more or remove some
    shellAliases = {
      vim = "nvim";

      # AI tools
      c = "claude";
      cr = "claude --resume";
      cy = "claude --dangerously-skip-permissions";
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
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      NIXOS_CONFIG = "$HOME/nixos-config";
      TMPDIR = "$HOME/.cache/tmp";
      NH_FLAKE = "$HOME/nixos-config"; # for nh on all platforms
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

      # sops-nix secrets (macOS path)
      [ -f "$HOME/.config/sops-nix/secrets/paperless_url" ] && export PAPERLESS_URL="$(cat "$HOME/.config/sops-nix/secrets/paperless_url")"
      [ -f "$HOME/.config/sops-nix/secrets/paperless_token" ] && export PAPERLESS_TOKEN="$(cat "$HOME/.config/sops-nix/secrets/paperless_token")"
      [ -f "$HOME/.config/sops-nix/secrets/x_to_obsidian_vault_path" ] && export X_TO_OBSIDIAN_VAULT_PATH="$(cat "$HOME/.config/sops-nix/secrets/x_to_obsidian_vault_path")"
      [ -f "$HOME/.config/sops-nix/secrets/x_to_obsidian_llm_provider" ] && export X_TO_OBSIDIAN_LLM_PROVIDER="$(cat "$HOME/.config/sops-nix/secrets/x_to_obsidian_llm_provider")"
      [ -f "$HOME/.config/sops-nix/secrets/x_to_obsidian_google_api_key" ] && export X_TO_OBSIDIAN_GOOGLE_API_KEY="$(cat "$HOME/.config/sops-nix/secrets/x_to_obsidian_google_api_key")"
      [ -f "$HOME/.config/sops-nix/secrets/fmcal_username" ] && export FMCAL_USERNAME="$(cat "$HOME/.config/sops-nix/secrets/fmcal_username")"
      [ -f "$HOME/.config/sops-nix/secrets/fmcal_password" ] && export FMCAL_PASSWORD="$(cat "$HOME/.config/sops-nix/secrets/fmcal_password")"
      [ -f "$HOME/.config/sops-nix/secrets/hass_server" ] && export HASS_SERVER="$(cat "$HOME/.config/sops-nix/secrets/hass_server")"
      [ -f "$HOME/.config/sops-nix/secrets/hass_token" ] && export HASS_TOKEN="$(cat "$HOME/.config/sops-nix/secrets/hass_token")"
      [ -f "$HOME/.config/sops-nix/secrets/flocasts_npm_token" ] && export FLOCASTS_NPM_TOKEN="$(cat "$HOME/.config/sops-nix/secrets/flocasts_npm_token")"
      [ -f "$HOME/.config/sops-nix/secrets/github_token" ] && export GITHUB_TOKEN="$(cat "$HOME/.config/sops-nix/secrets/github_token")"
      [ -f "$HOME/.config/sops-nix/secrets/jira_api_token" ] && export JIRA_API_TOKEN="$(cat "$HOME/.config/sops-nix/secrets/jira_api_token")"
      [ -f "$HOME/.config/sops-nix/secrets/dd_app_key" ] && export DD_APP_KEY="$(cat "$HOME/.config/sops-nix/secrets/dd_app_key")"
      [ -f "$HOME/.config/sops-nix/secrets/dd_api_key" ] && export DD_API_KEY="$(cat "$HOME/.config/sops-nix/secrets/dd_api_key")"
    '';

    shellAliases = {
      vim = "nvim";

      # AI tools
      c = "claude";
      cr = "claude --resume";
      cy = "claude --dangerously-skip-permissions";
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
    enableBashIntegration = true;
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
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # fzf - fuzzy finder
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  # eza - modern ls replacement
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
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
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
