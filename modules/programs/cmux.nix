{
  lib,
  pkgs,
  ...
}: {
  # cmux is a native macOS app installed via Homebrew in hosts/flomac/default.nix.
  # This module manages ~/.config/cmux/settings.json, cmux's declarative overrides
  # layer that takes precedence over the Application Support fallback written by
  # the app's UI. Only bindings we override are listed; everything else falls
  # back to cmux's built-in defaults.
  #
  # Keybindings are tuned to echo Grove's (~/projects/grove) muscle memory.
  # The "opt family" covers Grove's unmodified navigation keys:
  #   - opt+]/opt+[       next/prev surface   (Grove ]/[)
  #   - opt+j/opt+k       next/prev workspace (Grove Alt+J/Alt+K)
  #   - opt+1..9          select workspace N  (cmd+1..9 is taken by our
  #                       desktop-switcher symbolichotkeys in flomac)
  #   - cmd+/             workspace jump      (Grove /)
  #   - cmd+e             edit workspace      (Grove e)
  #   - cmd+k             command palette     (Grove ctrl+k)
  #   - ctrl+h/j/k/l      pane focus          (Grove h/j/k/l, matches zed.nix)
  #
  # Note: cmux's schema names nextSidebarTab/prevSidebarTab for what the UI
  # labels "Next Workspace"/"Previous Workspace" - same action, different name.
  xdg.configFile."cmux/settings.json" = lib.mkIf pkgs.stdenv.isDarwin {
    text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux-settings.schema.json";
      schemaVersion = 1;
      shortcuts = {
        bindings = {
          # Surface (tab) navigation, Grove ]/[
          nextSurface = "opt+]";
          prevSurface = "opt+[";

          # Workspace navigation (cmux UI labels these "Next/Previous Workspace").
          # opt+j/k matches Grove's Alt+J/K (down=next, up=prev).
          nextSidebarTab = "opt+j";
          prevSidebarTab = "opt+k";

          # Direct workspace selection. cmd+1..9 collides with flomac
          # symbolichotkeys desktop switcher; opt+1..9 matches the opt+j/k
          # workspace-nav family.
          selectWorkspaceByNumber = "opt+1";

          # Workspace jump palette and edit, Grove / and e
          goToWorkspace = "cmd+/";
          editWorkspaceDescription = "cmd+e";

          # Command palette, Grove ctrl+k (cmd+k is more mac-native)
          commandPalette = "cmd+k";

          # Pane focus, Grove h/j/k/l
          focusLeft = "ctrl+h";
          focusDown = "ctrl+j";
          focusUp = "ctrl+k";
          focusRight = "ctrl+l";
        };
      };
    };
  };
}
