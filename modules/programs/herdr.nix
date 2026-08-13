{
  config,
  lib,
  pkgs,
  ...
}: let
  # herdr reads ~/.config/herdr/config.toml. The binary is installed in
  # common.nix (inputs.llm-agents...herdr); this module owns the keybindings and
  # only lists what we override - everything else falls back to herdr's built-in
  # defaults (see `herdr --default-config`). Apply live with
  # `herdr server reload-config`.
  #
  # IMPORTANT: this is written via an activation script (install -Dm644), NOT
  # xdg.configFile. herdr treats config.toml as writable runtime state - it
  # stamps `onboarding = false` into it on first run - so a read-only symlink
  # into the nix store gets clobbered: herdr replaces the symlink with its own
  # plain file and our keybindings vanish. Writing a real, writable file (the
  # same pattern as modules/programs/agents/pi) lets herdr coexist, and the
  # `onboarding = false` below means herdr has nothing it needs to rewrite. Each
  # rebuild re-asserts our config; herdr's own runtime tweaks live in
  # session.json, not here.
  #
  # Design notes:
  #   - prefix = ctrl+; mirrors our zellij prefix (modules/programs/zellij.nix)
  #     so the multiplexer prefix is the same across both. Avoids ghostty's
  #     ctrl+a leader (modules/programs/ghostty.nix) and tmux's ctrl+b.
  #     If herdr rejects the ";" spelling, fall back to prefix = "ctrl+space".
  #   - Pane focus gets a direct ctrl+h/j/k/l duplicate alongside the default
  #     prefix+h/j/k/l, matching zellij/zed/cmux muscle memory. cmd+ is
  #     swallowed by macOS; ctrl+ and alt+ both reach the TUI - alt+ via
  #     ghostty's macos-option-as-alt = left (modules/programs/ghostty.nix),
  #     which frees the alt+ family for direct workspace/agent switching.
  tomlFormat = pkgs.formats.toml {};

  herdrConfig = tomlFormat.generate "herdr-config.toml" {
    # herdr writes this itself on first run; pre-set it so herdr never needs to
    # rewrite config.toml (which would otherwise drop our keybindings).
    onboarding = false;

    # Follow Ghostty/macOS appearance changes. Herdr forwards the same semantic
    # light/dark state to pane applications, allowing Pi to switch in sync.
    theme = {
      auto_switch = true;
      dark_name = "catppuccin";
      light_name = "catppuccin-latte";
    };

    keys = {
      prefix = "ctrl+;";

      # Pane focus: keep the prefix bind, add a direct ctrl+hjkl duplicate.
      focus_pane_left = ["prefix+h" "ctrl+h"];
      focus_pane_down = ["prefix+j" "ctrl+j"];
      focus_pane_up = ["prefix+k" "ctrl+k"];
      focus_pane_right = ["prefix+l" "ctrl+l"];

      # Navigate-mode movement. Panes keep herdr's vim default (h/j/k/l, no
      # override needed). Workspace nav can't reuse j/k - that collides with
      # pane up/down in navigate mode (herdr disables one) - and we want no
      # arrow keys, so workspaces move on shift+J/shift+K: same vim feel,
      # shifted for the higher-level nav.
      navigate_workspace_up = "shift+k";
      navigate_workspace_down = "shift+j";

      # Direct workspace switching: single-chord alt+j/k, no prefix and no
      # navigate mode. Needs ghostty's macos-option-as-alt = left so opt
      # arrives as alt on macOS. Navigate-mode shift+J/K above stays as the
      # in-mode equivalent.
      next_workspace = "alt+j";
      previous_workspace = "alt+k";

      # Agent panel nav (the vertical agent list in the sidebar). Direct
      # alt+shift+j/k mirrors the workspace chords one shift "up"; the prefix
      # comma/period binds stay for muscle memory. "comma" is in herdr's
      # documented punctuation list; "period" is NOT, so next_agent keeps
      # prefix+plus as a parseable fallback (same pattern as split_vertical's
      # backslash->v). After a rebuild, `herdr server reload-config` then check
      # herdr.log: if a chord is rejected the bind falls through to the next.
      previous_agent = ["prefix+comma" "alt+shift+k"];
      next_agent = ["prefix+period" "prefix+plus" "alt+shift+j"];

      # Direct tab switching: alt+[/]. Brackets are NOT in herdr's documented
      # punctuation list, and alt+[ is byte-identical to the CSI escape
      # introducer, so this depends on herdr's parser disambiguating (kitty
      # keyboard protocol). Default prefix+p/n stay as reliable fallbacks; if
      # the brackets don't register, swap these for alt+h/l instead.
      previous_tab = ["prefix+p" "alt+["];
      next_tab = ["prefix+n" "alt+]"];

      # Splits: prefix+\ vertical, prefix+- horizontal (usual muscle memory).
      # prefix+- is already herdr's default for split_horizontal, so only the
      # vertical bind moves off the default prefix+v. "backslash" is not in
      # herdr's documented punctuation list (minus/comma/ampersand/plus/backtick)
      # but is the spelling ghostty accepts; keep prefix+v as a fallback in case
      # herdr rejects it.
      split_vertical = ["prefix+backslash" "prefix+v"];
    };

    # Beep when background agents change state (settings > sound >
    # "sound alerts: on"). Set declaratively so a rebuild re-asserts it.
    ui.sound.enabled = true;
  };
in {
  home.activation.herdrConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    install -Dm644 ${herdrConfig} "$HOME/.config/herdr/config.toml"
  '';
}
