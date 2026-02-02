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
      [ -f /run/secrets/freshrss_api_user ] && export FRESHRSS_API_USER="$(cat /run/secrets/freshrss_api_user)"
      [ -f /run/secrets/freshrss_api_password ] && export FRESHRSS_API_PASSWORD="$(cat /run/secrets/freshrss_api_password)"
      [ -f /run/secrets/freshrss_url ] && export FRESHRSS_URL="$(cat /run/secrets/freshrss_url)"

      # Unbind C-j and C-l so tmux can use them for pane navigation
      if [[ $- == *i* ]]; then
        bind -r '\C-j'
        bind -r '\C-l'
      fi

      # tmux session picker (fzf)
      ta() {
        if [ -z "$TMUX" ]; then
          local session
          session=$(tmux ls -F '#{session_name}: #{session_windows} windows (#{session_attached} attached)' 2>/dev/null | fzf --header 'Attach to session' | cut -d: -f1)
          [ -n "$session" ] && tmux attach -t "$session"
        else
          echo "Already in tmux"
        fi
      }
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

      # tmux aliases
      tls = "tmux ls"; # list sessions
      tn = "tmux new -s"; # new session (usage: tn myname)
      tk = "tmux kill-session -t"; # kill session
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
      [ -f "$HOME/.config/sops-nix/secrets/freshrss_api_user" ] && export FRESHRSS_API_USER="$(cat "$HOME/.config/sops-nix/secrets/freshrss_api_user")"
      [ -f "$HOME/.config/sops-nix/secrets/freshrss_api_password" ] && export FRESHRSS_API_PASSWORD="$(cat "$HOME/.config/sops-nix/secrets/freshrss_api_password")"
      [ -f "$HOME/.config/sops-nix/secrets/freshrss_url" ] && export FRESHRSS_URL="$(cat "$HOME/.config/sops-nix/secrets/freshrss_url")"

      # Unbind C-j and C-l so tmux can use them for pane navigation
      bindkey -r "^J"
      bindkey -r "^L"
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

      # tmux aliases
      tls = "tmux ls"; # list sessions
      tn = "tmux new -s"; # new session (usage: tn myname)
      tk = "tmux kill-session -t"; # kill session
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

  # tmux - terminal multiplexer for persistent sessions
  programs.tmux = {
    enable = true;
    mouse = true;
    baseIndex = 1;
    historyLimit = 50000;
    keyMode = "vi";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_status_modules_right "directory session"
          set -g @catppuccin_window_text " #W "
          set -g @catppuccin_window_current_text " #W "
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'
        '';
      }
    ];
    extraConfig = ''
      # Prefix: Ctrl+;
      unbind C-b
      set -g prefix C-\;
      bind \; send-prefix

      # Reduce escape-time for vim mode switching
      set -s escape-time 0

      # Increase message display duration
      set -g display-time 4000

      # Refresh status more often
      set -g status-interval 5

      # 256 color and extended keys support
      set -g default-terminal "tmux-256color"
      set -s extended-keys on
      set -as terminal-features 'xterm*:extkeys'

      # Emacs keys in command prompt
      set -g status-keys emacs

      # Focus events for terminals that support them
      set -g focus-events on

      # Better multi-monitor support
      setw -g aggressive-resize on

      # Pane resizing with vim-like keys
      bind -r Down resize-pane -D 2
      bind -r Up resize-pane -U 2
      bind -r Right resize-pane -R 2
      bind -r Left resize-pane -L 2

      # Equalize panes
      bind -r DC select-layout tiled

      # Splits preserving current path
      unbind %
      unbind '"'
      bind \\ split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Kill pane
      bind x kill-pane

      # Maximize pane
      unbind z
      unbind m
      bind m resize-pane -Z

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # smart-splits.nvim integration (pane navigation)
      bind-key -n C-h if -F "#{@pane-is-vim}" 'send-keys C-h' 'select-pane -L'
      bind-key -n C-j if -F "#{@pane-is-vim}" 'send-keys C-j' 'select-pane -D'
      bind-key -n C-k if -F "#{@pane-is-vim}" 'send-keys C-k' 'select-pane -U'
      bind-key -n C-l if -F "#{@pane-is-vim}" 'send-keys C-l' 'select-pane -R'

      # smart-splits.nvim resizing
      bind-key -n M-h if -F "#{@pane-is-vim}" 'send-keys M-h' 'resize-pane -L 3'
      bind-key -n M-j if -F "#{@pane-is-vim}" 'send-keys M-j' 'resize-pane -D 3'
      bind-key -n M-k if -F "#{@pane-is-vim}" 'send-keys M-k' 'resize-pane -U 3'
      bind-key -n M-l if -F "#{@pane-is-vim}" 'send-keys M-l' 'resize-pane -R 3'

      # Copy mode with vim-like keybindings
      bind v copy-mode
      bind -T copy-mode-vi q send-keys -X cancel
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi V send-keys -X select-line
      bind -T copy-mode-vi Escape send-keys -X clear-selection
      bind -T copy-mode-vi 'C-v' send-keys -X rectangle-toggle
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "wl-copy"

      # Pane navigation in copy mode
      bind -T copy-mode-vi 'C-h' select-pane -L
      bind -T copy-mode-vi 'C-j' select-pane -D
      bind -T copy-mode-vi 'C-k' select-pane -U
      bind -T copy-mode-vi 'C-l' select-pane -R

      # Status bar at top
      set-option -g status-position top

      # Renumber windows when one is closed
      set-option -g renumber-windows on
      set-window-option -g pane-base-index 1

      # Don't auto-rename windows (keeps manual names)
      set-option -g allow-rename off
      set-window-option -g automatic-rename off

      # Help popup (prefix + ?)
      bind ? display-popup -E -w 60 -h 30 '\
        echo "tmux cheatsheet (press q to close)" && \
        echo "" && \
        echo "SESSIONS" && \
        echo "  prefix d     detach" && \
        echo "  prefix s     list sessions" && \
        echo "" && \
        echo "WINDOWS" && \
        echo "  prefix c     new window" && \
        echo "  prefix n/p   next/prev window" && \
        echo "  prefix 0-9   jump to window" && \
        echo "" && \
        echo "PANES" && \
        echo "  prefix \\     split horizontal" && \
        echo "  prefix -     split vertical" && \
        echo "  C-h/j/k/l    navigate (works in nvim)" && \
        echo "  prefix x     kill pane" && \
        echo "  prefix m     maximize/restore" && \
        echo "  prefix arrows resize panes" && \
        echo "" && \
        echo "COPY MODE" && \
        echo "  prefix v     enter copy mode" && \
        echo "  v/V          select / line select" && \
        echo "  y            copy to clipboard" && \
        echo "  q            exit copy mode" && \
        echo "" && \
        echo "OTHER" && \
        echo "  prefix r     reload config" && \
        echo "  prefix ?     this help" && \
        echo "" && \
        read -n 1'
    '';
  };
}
