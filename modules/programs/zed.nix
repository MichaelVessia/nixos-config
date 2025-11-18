{
  pkgs-unstable,
  lib,
  ...
}: {
  programs.zed-editor = {
    enable = true;
    package = pkgs-unstable.zed-editor;

    # === EXTENSIONS ===
    extensions = [
      "nix"
      "toml"
      "lua"
      "basher"
      "catppuccin"
      "typescript"
      "biome"
    ];

    # === EXTRA PACKAGES ===
    extraPackages = [pkgs-unstable.nixd pkgs-unstable.nodejs_22 pkgs-unstable.biome];

    # === USER SETTINGS ===
    userSettings = {
      # === VIM MODE ===
      vim_mode = true;
      vim = {
        use_system_clipboard = "never";
        toggle_relative_line_numbers = true;
      };

      # === APPEARANCE ===
      theme = {
        mode = "system";
        light = "Catppuccin Latte";
        dark = "Catppuccin Mocha";
      };
      ui_font_size = lib.mkForce 12;
      buffer_font_size = lib.mkForce 14;
      inactive_opacity = "0.5";
      indent_guides = {
        enabled = true;
        coloring = "indent_aware";
      };
      inlay_hints = {
        enabled = true;
      };

      # === UI LAYOUT ===
      file_finder = {
        modal_width = "medium";
      };
      tab_bar = {
        show = true;
      };
      tabs = {
        show_diagnostics = "errors";
      };
      outline_panel = {
        dock = "right";
      };
      collaboration_panel = {
        dock = "left";
      };
      notification_panel = {
        dock = "left";
      };
      chat_panel = {
        dock = "left";
      };

      # === NODE CONFIGURATION ===
      node = {
        path = lib.getExe pkgs-unstable.nodejs_22;
        npm_path = lib.getExe' pkgs-unstable.nodejs_22 "npm";
      };

      # === GENERAL SETTINGS ===
      hour_format = "hour12";
      auto_update = false;
      auto_install_extensions = true;

      # === TERMINAL ===
      terminal = {
        alternate_scroll = "off";
        blinking = "off";
        copy_on_select = false;
        dock = "bottom";
        detect_venv = {
          on = {
            directories = [
              ".env"
              "env"
              ".venv"
              "venv"
            ];
            activate_script = "default";
          };
        };
        env = {
          EDITOR = "zed --wait";
          TERM = "ghostty";
        };
        font_features = null;
        line_height = "comfortable";
        option_as_meta = false;
        button = false;
        shell = "system";
        toolbar = {
          title = true;
        };
        working_directory = "current_project_directory";
      };

      # === FILE TYPES ===
      file_types = {
        JSON = [
          "json"
          "jsonc"
          "*.code-snippets"
        ];
      };

      # === LANGUAGE CONFIGURATION ===
      languages = {
        NIX = {
          formatter = "alejandra";
        };
      };

      # === LSP CONFIGURATION ===
      lsp = {
        nix = {
          binary = {
            path_lookup = true;
          };
        };
        typescript-language-server = {
          binary = {
            path_lookup = true;
          };
        };
        settings = {
          dialyzerEnabled = true;
        };
      };
    };

    # === USER KEYMAPS ===
    userKeymaps = [
      {
        context = "Editor && (vim_mode == normal || vim_mode == visual) && !VimWaiting && !menu";
        bindings = {
          # === GIT ===
          "space g h d" = "editor::ToggleSelectedDiffHunks";
          "space g s" = "git_panel::ToggleFocus";

          # === TOGGLES ===
          "space t i" = "editor::ToggleInlayHints";
          "space u w" = "editor::ToggleSoftWrap";
          "space c z" = "workspace::ToggleCenteredLayout";

          # === MARKDOWN ===
          "space m p" = "markdown::OpenPreview";
          "space m P" = "markdown::OpenPreviewToTheSide";

          # === FILES ===
          "space f p" = "projects::OpenRecent";
          "space s w" = "pane::DeploySearch";

          # === AI ===
          "space a c" = "assistant::ToggleFocus";

          # === NAVIGATION ===
          "g f" = "editor::OpenExcerpts";
        };
      }
      {
        context = "Editor && vim_mode == normal && !VimWaiting && !menu";
        bindings = {
          # === WINDOW MOVEMENT ===
          "ctrl-h" = "workspace::ActivatePaneLeft";
          "ctrl-l" = "workspace::ActivatePaneRight";
          "ctrl-k" = "workspace::ActivatePaneUp";
          "ctrl-j" = "workspace::ActivatePaneDown";

          # === LSP ===
          "space c a" = "editor::ToggleCodeActions";
          "space ." = "editor::ToggleCodeActions";
          "space c r" = "editor::Rename";
          "g d" = "editor::GoToDefinition";
          "g D" = "editor::GoToDefinitionSplit";
          "g i" = "editor::GoToImplementation";
          "g I" = "editor::GoToImplementationSplit";
          "g t" = "editor::GoToTypeDefinition";
          "g T" = "editor::GoToTypeDefinitionSplit";
          "g r" = "editor::FindAllReferences";
          "] d" = "editor::GoToDiagnostic";
          "[ d" = "editor::GoToPreviousDiagnostic";
          "] e" = "editor::GoToDiagnostic";
          "[ e" = "editor::GoToPreviousDiagnostic";

          # === SYMBOL SEARCH ===
          "s s" = "outline::Toggle";
          "s S" = "project_symbols::Toggle";
          "space x x" = "diagnostics::Deploy";

          # === GIT ===
          "] h" = "editor::GoToHunk";
          "[ h" = "editor::GoToPreviousHunk";

          # === BUFFERS ===
          "shift-h" = "pane::ActivatePreviousItem";
          "shift-l" = "pane::ActivateNextItem";
          "shift-q" = "pane::CloseActiveItem";
          "ctrl-q" = "pane::CloseActiveItem";
          "space b d" = "pane::CloseActiveItem";
          "space b o" = "pane::CloseInactiveItems";

          # === FILE OPERATIONS ===
          "ctrl-s" = "workspace::Save";
          "space space" = "file_finder::Toggle";
          "space /" = "pane::DeploySearch";
          "space e" = "workspace::ToggleLeftDock";
        };
      }
      {
        context = "EmptyPane || SharedScreen";
        bindings = {
          "space space" = "file_finder::Toggle";
          "space f p" = "projects::OpenRecent";
        };
      }
      {
        context = "Editor && vim_mode == visual && !VimWaiting && !menu";
        bindings = {
          "g c" = "editor::ToggleComments";
        };
      }
      {
        context = "Editor && vim_mode == insert && !menu";
        bindings = {
          "j j" = "vim::NormalBefore";
          "j k" = "vim::NormalBefore";
        };
      }
      {
        context = "Editor && vim_operator == c";
        bindings = {
          "c" = "vim::CurrentLine";
          "r" = "editor::Rename";
        };
      }
      {
        context = "Editor && vim_operator == c";
        bindings = {
          "c" = "vim::CurrentLine";
          "a" = "editor::ToggleCodeActions";
        };
      }
      {
        context = "Workspace";
        bindings = {
          "ctrl-`" = "terminal_panel::ToggleFocus";
        };
      }
      {
        context = "Terminal";
        bindings = {
          "ctrl-h" = "workspace::ActivatePaneLeft";
          "ctrl-l" = "workspace::ActivatePaneRight";
          "ctrl-k" = "workspace::ActivatePaneUp";
          "ctrl-j" = "workspace::ActivatePaneDown";
        };
      }
      {
        context = "ProjectPanel && not_editing";
        bindings = {
          "a" = "project_panel::NewFile";
          "A" = "project_panel::NewDirectory";
          "r" = "project_panel::Rename";
          "d" = "project_panel::Delete";
          "x" = "project_panel::Cut";
          "c" = "project_panel::Copy";
          "p" = "project_panel::Paste";
          "q" = "workspace::ToggleRightDock";
          "space e" = "project_panel::ToggleFocus";
          "ctrl-h" = "workspace::ActivatePaneLeft";
          "ctrl-l" = "workspace::ActivatePaneRight";
          "ctrl-k" = "workspace::ActivatePaneUp";
          "ctrl-j" = "workspace::ActivatePaneDown";
        };
      }
      {
        context = "Dock";
        bindings = {
          "ctrl-w h" = "workspace::ActivatePaneLeft";
          "ctrl-w l" = "workspace::ActivatePaneRight";
          "ctrl-w k" = "workspace::ActivatePaneUp";
          "ctrl-w j" = "workspace::ActivatePaneDown";
        };
      }
      {
        context = "EmptyPane || SharedScreen || vim_mode == normal";
        bindings = {
          "space r t" = ["editor::SpawnNearestTask" {reveal = "no_focus";}];
        };
      }
      {
        context = "vim_mode == normal || vim_mode == visual";
        bindings = {
          "s" = ["vim::PushSneak" {}];
          "S" = ["vim::PushSneakBackward" {}];
        };
      }
    ];
  };
}
