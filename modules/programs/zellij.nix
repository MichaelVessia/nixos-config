{...}: {
  programs.zellij = {
    enable = true;
  };

  xdg.configFile."zellij/layouts/default.kdl".text = ''
    layout {
      pane

      swap_tiled_layout name="vertical" {
        tab max_panes=5 {
          pane split_direction="vertical" {
            pane
            pane { children; }
          }
        }
        tab max_panes=8 {
          pane split_direction="vertical" {
            pane { children; }
            pane { pane; pane; pane; pane; }
          }
        }
      }

      swap_tiled_layout name="horizontal" {
        tab max_panes=5 {
          pane
          pane
        }
      }

      swap_tiled_layout name="grid" {
        tab max_panes=2 {
          pane split_direction="vertical" {
            pane
            pane
          }
        }
        tab max_panes=5 {
          pane split_direction="vertical" {
            pane split_direction="horizontal" {
              pane
              pane
            }
            pane split_direction="horizontal" {
              pane
              pane
            }
          }
        }
      }
    }
  '';

  xdg.configFile."zellij/config.kdl".text = ''
    // Catppuccin Mocha theme
    theme "catppuccin-mocha"

    // Use system clipboard
    copy_on_select true

    // Mouse support
    mouse_mode true

    // Scroll buffer (equivalent to tmux historyLimit)
    scroll_buffer_size 50000

    // Pane numbering starts at 1
    pane_frames true

    // Session serialization (equivalent to tmux-resurrect/continuum)
    session_serialization true
    serialize_pane_viewport true

    // Mirror tmux prefix style: use Ctrl+; as custom prefix via keybindings
    // Zellij uses modes instead of prefix keys. We configure keybindings below.

    keybinds clear-defaults=true {
      // --- Normal mode (default when typing in terminal) ---
      normal {
        // Pane navigation (Ctrl-hjkl)
        bind "Ctrl h" { MoveFocus "Left"; }
        bind "Ctrl j" { MoveFocus "Down"; }
        bind "Ctrl k" { MoveFocus "Up"; }
        bind "Ctrl l" { MoveFocus "Right"; }

        // Pane resizing (matches tmux Alt-hjkl)
        bind "Alt h" { Resize "Increase Left"; }
        bind "Alt j" { Resize "Increase Down"; }
        bind "Alt k" { Resize "Increase Up"; }
        bind "Alt l" { Resize "Increase Right"; }

        // Enter other modes
        bind "Ctrl ;" { SwitchToMode "Tmux"; }
      }

      // --- Tmux-compatible prefix mode (Ctrl+; then key) ---
      tmux {
        // Splits (matching tmux \ and -)
        bind "\\" { NewPane "Right"; SwitchToMode "Normal"; }
        bind "-" { NewPane "Down"; SwitchToMode "Normal"; }

        // New tab (like tmux prefix c)
        bind "c" { NewTab; SwitchToMode "Normal"; }

        // Tab navigation (like tmux prefix n/p)
        bind "n" { GoToNextTab; SwitchToMode "Normal"; }
        bind "p" { GoToPreviousTab; SwitchToMode "Normal"; }

        // Jump to tab by number (like tmux prefix 0-9)
        bind "1" { GoToTab 1; SwitchToMode "Normal"; }
        bind "2" { GoToTab 2; SwitchToMode "Normal"; }
        bind "3" { GoToTab 3; SwitchToMode "Normal"; }
        bind "4" { GoToTab 4; SwitchToMode "Normal"; }
        bind "5" { GoToTab 5; SwitchToMode "Normal"; }
        bind "6" { GoToTab 6; SwitchToMode "Normal"; }
        bind "7" { GoToTab 7; SwitchToMode "Normal"; }
        bind "8" { GoToTab 8; SwitchToMode "Normal"; }
        bind "9" { GoToTab 9; SwitchToMode "Normal"; }

        // Kill pane (like tmux prefix x)
        bind "x" { CloseFocus; SwitchToMode "Normal"; }

        // Zoom/maximize toggle (like tmux prefix z/m)
        bind "z" { ToggleFocusFullscreen; SwitchToMode "Normal"; }
        bind "m" { ToggleFocusFullscreen; SwitchToMode "Normal"; }

        // Floating pane toggle
        bind "f" { ToggleFloatingPanes; SwitchToMode "Normal"; }

        // Detach (like tmux prefix d)
        bind "d" { Detach; }

        // Session manager (like tmux prefix s)
        bind "s" {
          LaunchOrFocusPlugin "session-manager" {
            floating true
            move_to_focused_tab true
          };
          SwitchToMode "Normal";
        }

        // Enter scroll/copy mode (like tmux prefix v)
        bind "v" { SwitchToMode "Scroll"; }

        // Rename tab / pane (, and . like vim buffers)
        bind "," { SwitchToMode "RenameTab"; TabNameInput 0; }
        bind "." { SwitchToMode "RenamePane"; PaneNameInput 0; }

        // Cycle layout (grid, vertical, horizontal, etc.)
        bind "Space" { NextSwapLayout; SwitchToMode "Normal"; }

        // Move pane in direction (prefix + Shift-hjkl)
        bind "H" { MovePane "Left"; SwitchToMode "Normal"; }
        bind "J" { MovePane "Down"; SwitchToMode "Normal"; }
        bind "K" { MovePane "Up"; SwitchToMode "Normal"; }
        bind "L" { MovePane "Right"; SwitchToMode "Normal"; }

        // Move tab left/right (prefix + Shift-p/n, mirrors p/n navigation)
        bind "P" { MoveTab "Left"; SwitchToMode "Normal"; }
        bind "N" { MoveTab "Right"; SwitchToMode "Normal"; }

        // Cancel back to normal
        bind "Esc" { SwitchToMode "Normal"; }
        bind "Ctrl ;" { SwitchToMode "Normal"; }
      }

      // --- Scroll mode (read-only navigation) ---
      scroll {
        bind "j" { ScrollDown; }
        bind "k" { ScrollUp; }
        bind "d" { HalfPageScrollDown; }
        bind "u" { HalfPageScrollUp; }
        bind "Ctrl f" { PageScrollDown; }
        bind "Ctrl b" { PageScrollUp; }

        // Enter search
        bind "/" { SwitchToMode "EnterSearch"; SearchInput 0; }

        // Enter selection (copy) mode
        bind "v" { SwitchToMode "Search"; }

        bind "q" { SwitchToMode "Normal"; }
        bind "Esc" { SwitchToMode "Normal"; }
      }

      // --- Search entry mode ---
      entersearch {
        bind "Enter" { SwitchToMode "Search"; }
        bind "Esc" { SwitchToMode "Scroll"; }
      }

      // --- Search mode (after entering search term) ---
      search {
        bind "j" { ScrollDown; }
        bind "k" { ScrollUp; }
        bind "d" { HalfPageScrollDown; }
        bind "u" { HalfPageScrollUp; }
        bind "n" { Search "down"; }
        bind "N" { Search "up"; }

        bind "q" { SwitchToMode "Normal"; }
        bind "Esc" { SwitchToMode "Normal"; }
      }

      // --- Rename tab mode ---
      renametab {
        bind "Enter" { SwitchToMode "Normal"; }
        bind "Esc" { UndoRenameTab; SwitchToMode "Normal"; }
      }

      // --- Rename pane mode ---
      renamepane {
        bind "Enter" { SwitchToMode "Normal"; }
        bind "Esc" { UndoRenamePane; SwitchToMode "Normal"; }
      }

      // --- Shared across all modes ---
      shared_except "normal" {
        bind "Ctrl ;" { SwitchToMode "Normal"; }
      }
    }
  '';
}
