# Niri Compositor - Home Manager Configuration
# Based on github:jordangarrison/nix-config
# Alt is the primary modifier (swapped from default Super)
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  osConfig ? null,
  ...
}: let
  hostname =
    if osConfig != null
    then osConfig.networking.hostName
    else null;

  desktopShell = "dank";
  useDank = desktopShell == "dank";
  dmsNiriIncludeFiles = ["alttab" "binds" "colors" "layout" "outputs" "wpblur"];
  dmsNiriConfigText = borderEnabled:
    builtins.concatStringsSep "\n" (
      ["include \"hm.kdl\""]
      ++ map (filename: "include \"dms/${filename}.kdl\"") dmsNiriIncludeFiles
      ++ lib.optional borderEnabled ''
        // Border fix
        // See https://yalter.github.io/niri/Configuration%3A-Include.html#border-special-case for details
        layout { border { on; }; }
      ''
    )
    + "\n";
  pactlPath = "${pkgs.pulseaudio}/bin/pactl";
  audioDefaultDevicePatch = pkgs.writeText "dms-audio-default-device-button.patch" ''
    --- Services/AudioService.qml
    +++ Services/AudioService.qml
    @@ -67,6 +67,36 @@
         signal wireplumberReloadStarted
         signal wireplumberReloadCompleted(bool success)

    +    function shellSingleQuote(value) {
    +        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    +    }
    +
    +    function setPulseDefaultSinkByName(name) {
    +        const quotedName = shellSingleQuote(name);
    +        const command = "${pactlPath} set-default-sink " + quotedName + "\n" +
    +            "${pactlPath} list short sink-inputs | while read -r input _; do " +
    +            "[ -n \"$input\" ] && ${pactlPath} move-sink-input \"$input\" " + quotedName + " || true; " +
    +            "done";
    +        Proc.runCommand("setPulseDefaultSinkByName", ["sh", "-c", command], (output, exitCode) => {
    +            if (exitCode !== 0) {
    +                console.error("AudioService: Failed to set default Pulse sink:", output);
    +            }
    +        }, 0);
    +    }
    +
    +    function setPulseDefaultSourceByName(name) {
    +        const quotedName = shellSingleQuote(name);
    +        const command = "${pactlPath} set-default-source " + quotedName + "\n" +
    +            "${pactlPath} list short source-outputs | while read -r output _; do " +
    +            "[ -n \"$output\" ] && ${pactlPath} move-source-output \"$output\" " + quotedName + " || true; " +
    +            "done";
    +        Proc.runCommand("setPulseDefaultSourceByName", ["sh", "-c", command], (output, exitCode) => {
    +            if (exitCode !== 0) {
    +                console.error("AudioService: Failed to set default Pulse source:", output);
    +            }
    +        }, 0);
    +    }
    +
         function getMaxVolumePercent(node) {
             if (!node?.name)
                 return 100;
    --- Modules/Settings/Widgets/DeviceAliasRow.qml
    +++ Modules/Settings/Widgets/DeviceAliasRow.qml
    @@ -15,10 +15,13 @@ Rectangle {

         property bool showHideButton: false
         property bool isHidden: false
    +    property bool showDefaultButton: false
    +    property bool isDefaultDevice: false

         signal editRequested(var deviceNode)
         signal resetRequested(var deviceNode)
         signal hideRequested(var deviceNode)
    +    signal defaultRequested(var deviceNode)

         width: parent?.width ?? 0
         height: deviceRowContent.height + Theme.spacingM * 2
    @@ -119,6 +122,23 @@ Rectangle {
                 anchors.verticalCenter: parent.verticalCenter
                 spacing: Theme.spacingS

    +            DankActionButton {
    +                id: defaultButton
    +                visible: root.showDefaultButton && !root.isHidden
    +                buttonSize: 36
    +                iconName: root.isDefaultDevice ? "radio_button_checked" : "radio_button_unchecked"
    +                iconSize: 20
    +                backgroundColor: root.isDefaultDevice ? Theme.withAlpha(Theme.primary, 0.15) : Theme.surfaceContainerHigh
    +                iconColor: root.isDefaultDevice ? Theme.primary : Theme.surfaceVariantText
    +                tooltipText: root.isDefaultDevice ? I18n.tr("Default device") : I18n.tr("Set default device")
    +                anchors.verticalCenter: parent.verticalCenter
    +                onClicked: {
    +                    if (!root.isDefaultDevice) {
    +                        root.defaultRequested(root.deviceNode);
    +                    }
    +                }
    +            }
    +
                 DankActionButton {
                     id: resetButton
                     visible: root.hasCustomAlias
    --- Modules/Settings/AudioTab.qml
    +++ Modules/Settings/AudioTab.qml
    @@ -136,7 +136,7 @@ Item {

                         StyledText {
                             width: parent.width
    -                        text: I18n.tr("Set custom names for your audio output devices", "Audio settings description")
    +                        text: I18n.tr("Choose the default output device, set custom names, and adjust limits", "Audio settings description")
                             font.pixelSize: Theme.fontSizeSmall
                             color: Theme.surfaceVariantText
                             wrapMode: Text.WordWrap
    @@ -164,6 +164,8 @@ Item {
                                     deviceNode: modelData
                                     deviceType: "output"
                                     showHideButton: true
    +                                showDefaultButton: true
    +                                isDefaultDevice: modelData === AudioService.sink

                                     onEditRequested: device => {
                                         root.editingDevice = device;
    @@ -180,6 +182,11 @@ Item {
                                     onHideRequested: device => {
                                         root.persistHiddenOutputDeviceNames([...root.hiddenOutputDeviceNames, device.name]);
                                     }
    +
    +                                onDefaultRequested: device => {
    +                                    AudioService.setDefaultSinkByName(device.name);
    +                                    root.updateDeviceList();
    +                                }
                                 }

                                 Item {
    @@ -327,7 +334,7 @@ Item {

                         StyledText {
                             width: parent.width
    -                        text: I18n.tr("Set custom names for your audio input devices", "Audio settings description")
    +                        text: I18n.tr("Choose the default input device and set custom names", "Audio settings description")
                             font.pixelSize: Theme.fontSizeSmall
                             color: Theme.surfaceVariantText
                             wrapMode: Text.WordWrap
    @@ -350,6 +357,8 @@ Item {
                                 deviceNode: modelData
                                 deviceType: "input"
                                 showHideButton: true
    +                            showDefaultButton: true
    +                            isDefaultDevice: modelData === AudioService.source

                                 onEditRequested: device => {
                                     root.editingDevice = device;
    @@ -366,6 +375,11 @@ Item {
                                 onHideRequested: device => {
                                     root.persistHiddenInputDeviceNames([...root.hiddenInputDeviceNames, device.name]);
                                 }
    +
    +                            onDefaultRequested: device => {
    +                                AudioService.setDefaultSourceByName(device.name);
    +                                root.updateDeviceList();
    +                            }
                             }
                         }

  '';
  dmsPackage = let
    unpatchedDmsPackage = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in
    pkgs.runCommand "${unpatchedDmsPackage.name}-framework13" {
      nativeBuildInputs = [pkgs.gnupatch];
      meta = (unpatchedDmsPackage.meta or {}) // {mainProgram = "dms";};
    } ''
      cp -a ${unpatchedDmsPackage} $out
      chmod -R u+w $out

      patch -d $out/share/quickshell/dms -p0 < ${audioDefaultDevicePatch}

      substituteInPlace $out/share/quickshell/dms/Services/AudioService.qml \
        --replace-fail 'Pipewire.preferredDefaultAudioSink = node;' 'Pipewire.preferredDefaultAudioSink = node;
                setPulseDefaultSinkByName(name);' \
        --replace-fail 'Pipewire.preferredDefaultAudioSource = node;' 'Pipewire.preferredDefaultAudioSource = node;
                setPulseDefaultSourceByName(name);'

      substituteInPlace $out/bin/dms $out/share/systemd/user/dms.service \
        --replace-fail ${unpatchedDmsPackage} $out

      substituteInPlace $out/share/quickshell/dms/Services/AudioService.qml \
        --replace-fail 'readonly property bool soundsAvailable: MultimediaService.available' \
          'readonly property bool soundsAvailable: false'
    '';
in
  lib.mkIf pkgs.stdenv.isLinux {
    # Clipboard services via Home Manager (systemd-managed)
    services.cliphist = {
      enable = true;
      allowImages = true;
      systemdTargets = ["graphical-session.target"];
    };

    # Clipboard persistence disabled - conflicts with cliphist causing race conditions
    # cliphist provides sufficient persistence through its history feature
    services.wl-clip-persist.enable = false;

    # Ensure screenshot/recording directories exist
    home.file."Pictures/Screenshots/.keep".text = "";
    home.file."Videos/.keep".text = "";

    programs.dank-material-shell = lib.mkIf useDank {
      enable = true;
      package = dmsPackage;
      quickshell.package = pkgs-unstable.quickshell;
      systemd.enable = true;
      niri = {
        enableSpawn = false;
        enableKeybinds = false;
        includes = {
          enable = true;
          filesToInclude = dmsNiriIncludeFiles;
        };
      };
      enableSystemMonitoring = true;
      enableDynamicTheming = true;
      enableClipboardPaste = true;
      enableVPN = true;
      enableAudioWavelength = true;
      enableCalendarEvents = false;
      dgop.package = inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };

    # DMS emits obsolete `include optional=true` syntax that niri 25.11 rejects.
    # Keep the same include order, but override the generated wrapper with
    # current niri include syntax until upstream updates its Home Manager module.
    xdg.configFile."niri-config-dms" = lib.mkIf useDank {
      target = "niri/config.kdl";
      text = lib.mkForce (dmsNiriConfigText config.programs.niri.settings.layout.border.enable);
    };

    # Packages needed for niri desktop environment
    home.packages = with pkgs; [
      # Clipboard
      wl-clipboard
      cliphist
      wtype # for Handy paste on Wayland

      # Screenshot/recording tools
      grim
      slurp
      # Notifications
      libnotify

      # System tray applets
      networkmanagerapplet
      blueman

      # Authentication
      polkit_gnome
    ];

    programs.niri = {
      enable = true;
      package = pkgs.niri;

      settings = {
        # Prefer server-side decorations
        prefer-no-csd = true;

        # Input configuration
        input = {
          keyboard = {
            xkb = {
              layout = "us";
              # Swap Alt and Super so Alt is the modifier
              options = "altwin:swap_alt_win,lv3:ralt_switch";
            };
            repeat-delay = 300;
            repeat-rate = 50;
          };

          touchpad = {
            tap = true;
            natural-scroll = false;
            dwt = true; # Disable while typing
          };

          mouse = {accel-profile = "flat";};

          # Focus follows mouse but don't scroll
          focus-follows-mouse = {
            enable = true;
            max-scroll-amount = "0%";
          };
        };

        # Layout configuration
        layout = {
          gaps = 8;

          # Column widths that can be cycled through
          preset-column-widths = [
            {proportion = 1.0 / 3.0;}
            {proportion = 1.0 / 2.0;}
            {proportion = 2.0 / 3.0;}
            {proportion = 9.0 / 10.0;}
            {proportion = 1.0;}
          ];

          # Default column width
          default-column-width = {proportion = 1.0 / 2.0;};

          # Focus ring (drawn outside windows) - Rose Pine theme
          focus-ring = {
            enable = true;
            width = 2;
            active.color = "#9ccfd8"; # Foam (cyan)
            inactive.color = "#6e6a86"; # Muted
          };

          # Border (drawn inside windows)
          border = {enable = false;};

          # Shadows
          shadow = {enable = true;};

          # Center focused column only when it doesn't fit
          center-focused-column = "on-overflow";
        };

        # Dank Material Shell provides native network and Bluetooth widgets.
        spawn-at-startup = [];

        # Environment variables
        environment = {
          NIXOS_OZONE_WL = "1";
          QT_QPA_PLATFORM = "wayland";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          GDK_BACKEND = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
          XDG_CURRENT_DESKTOP = "niri";
        };

        # Window rules
        window-rules = [
          # Default rule for all windows: rounded corners
          {
            geometry-corner-radius = let
              r = 8.0;
            in {
              top-left = r;
              top-right = r;
              bottom-left = r;
              bottom-right = r;
            };
            clip-to-geometry = true;
            draw-border-with-background = false;
          }
          # Float authentication dialogs
          {
            matches = [{app-id = "^polkit-gnome-authentication-agent-1$";}];
            open-floating = true;
          }
          # Float file picker dialogs
          {
            matches = [{app-id = "^xdg-desktop-portal.*$";}];
            open-floating = true;
          }
          # Float pavucontrol
          {
            matches = [{app-id = "^pavucontrol$";}];
            open-floating = true;
          }
          # Float blueman
          {
            matches = [{app-id = "^blueman-manager$";}];
            open-floating = true;
          }
          # Float nm-connection-editor
          {
            matches = [{app-id = "^nm-connection-editor$";}];
            open-floating = true;
          }
        ];

        # Keybindings
        # With altwin:swap_alt_win, physical Alt becomes Mod
        binds = {
          # ==================
          # PROGRAM LAUNCHERS
          # ==================
          "Mod+Return".action.spawn = "ghostty";
          "Mod+B".action.spawn = "brave";
          "Mod+E".action.spawn = "nautilus";
          # Handy transcription toggle (Alt+` with swap)
          "Mod+Grave".action.spawn = ["pkill" "-USR2" "handy"];

          # ================
          # WINDOW CONTROLS
          # ================
          "Mod+Q".action.close-window = [];
          "Mod+V".action.toggle-window-floating = [];
          "Mod+M".action.maximize-column = [];
          "Mod+Shift+M".action.fullscreen-window = [];

          # ================
          # FOCUS MOVEMENT (vim-style)
          # ================
          "Mod+H".action.focus-column-left = [];
          "Mod+L".action.focus-column-right = [];
          "Mod+K".action.focus-window-up = [];
          "Mod+J".action.focus-window-down = [];

          # Arrow key alternatives
          "Mod+Left".action.focus-column-left = [];
          "Mod+Right".action.focus-column-right = [];
          "Mod+Up".action.focus-window-up = [];
          "Mod+Down".action.focus-window-down = [];

          # ================
          # WINDOW MOVEMENT
          # ================
          "Mod+Shift+H".action.move-column-left = [];
          "Mod+Shift+L".action.move-column-right = [];
          "Mod+Shift+K".action.move-window-up = [];
          "Mod+Shift+J".action.move-window-down = [];

          # Arrow key alternatives
          "Mod+Shift+Left".action.move-column-left = [];
          "Mod+Shift+Right".action.move-column-right = [];
          "Mod+Shift+Up".action.move-window-up = [];
          "Mod+Shift+Down".action.move-window-down = [];

          # ================
          # COLUMN/WINDOW SIZING
          # ================
          "Mod+Minus".action.set-column-width = "-10%";
          "Mod+Equal".action.set-column-width = "+10%";
          "Mod+Shift+Minus".action.set-window-height = "-10%";
          "Mod+Shift+Equal".action.set-window-height = "+10%";
          "Mod+R".action.switch-preset-column-width = [];

          # ================
          # WORKSPACES
          # ================
          "Mod+1".action.focus-workspace = 1;
          "Mod+2".action.focus-workspace = 2;
          "Mod+3".action.focus-workspace = 3;
          "Mod+4".action.focus-workspace = 4;
          "Mod+5".action.focus-workspace = 5;
          "Mod+6".action.focus-workspace = 6;
          "Mod+7".action.focus-workspace = 7;
          "Mod+8".action.focus-workspace = 8;
          "Mod+9".action.focus-workspace = 9;
          "Mod+0".action.focus-workspace = 10;

          # Move window to workspace
          "Mod+Shift+1".action.move-window-to-workspace = 1;
          "Mod+Shift+2".action.move-window-to-workspace = 2;
          "Mod+Shift+3".action.move-window-to-workspace = 3;
          "Mod+Shift+4".action.move-window-to-workspace = 4;
          "Mod+Shift+5".action.move-window-to-workspace = 5;
          "Mod+Shift+6".action.move-window-to-workspace = 6;
          "Mod+Shift+7".action.move-window-to-workspace = 7;
          "Mod+Shift+8".action.move-window-to-workspace = 8;
          "Mod+Shift+9".action.move-window-to-workspace = 9;
          "Mod+Shift+0".action.move-window-to-workspace = 10;

          # Workspace navigation
          "Mod+Page_Down".action.focus-workspace-down = [];
          "Mod+Page_Up".action.focus-workspace-up = [];
          "Mod+Shift+Page_Down".action.move-window-to-workspace-down = [];
          "Mod+Shift+Page_Up".action.move-window-to-workspace-up = [];

          # ================
          # MULTI-MONITOR
          # ================
          "Mod+Comma".action.focus-monitor-left = [];
          "Mod+Period".action.focus-monitor-right = [];
          "Mod+Shift+Comma".action.move-window-to-monitor-left = [];
          "Mod+Shift+Period".action.move-window-to-monitor-right = [];

          # ================
          # NIRI-SPECIFIC
          # ================
          "Mod+Tab".action.toggle-overview = [];
          "Mod+Ctrl+H".action.consume-window-into-column = [];
          "Mod+Ctrl+L".action.expel-window-from-column = [];
          "Mod+T".action.toggle-column-tabbed-display = [];
          "Mod+G".action.center-column = [];

          # ================
          # SCREENSHOTS & RECORDING
          # ================
          "Print".action.screenshot = [];
          "Shift+Print".action.screenshot-window = [];
          "Ctrl+Shift+4".action.spawn = ["sh" "-c" "grim -g \"$(slurp)\" - | wl-copy && notify-send 'Screenshot copied'"];
          # ================
          # MEDIA KEYS
          # ================
          "XF86AudioRaiseVolume" = {
            allow-when-locked = true;
            action.spawn = ["wpctl" "set-volume" "-l" "1.0" "@DEFAULT_AUDIO_SINK@" "5%+"];
          };
          "XF86AudioLowerVolume" = {
            allow-when-locked = true;
            action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"];
          };
          "XF86AudioMute" = {
            allow-when-locked = true;
            action.spawn = ["wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
          };
          "XF86AudioMicMute" = {
            allow-when-locked = true;
            action.spawn = ["wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"];
          };
          "XF86MonBrightnessUp" = {
            allow-when-locked = true;
            action.spawn = ["brightnessctl" "-e4" "-n2" "set" "5%+"];
          };
          "XF86MonBrightnessDown" = {
            allow-when-locked = true;
            action.spawn = ["brightnessctl" "-e4" "-n2" "set" "5%-"];
          };
          "XF86AudioNext" = {
            allow-when-locked = true;
            action.spawn = ["playerctl" "next"];
          };
          "XF86AudioPrev" = {
            allow-when-locked = true;
            action.spawn = ["playerctl" "previous"];
          };
          "XF86AudioPlay" = {
            allow-when-locked = true;
            action.spawn = ["playerctl" "play-pause"];
          };

          # ================
          # SYSTEM
          # ================
          "Mod+Shift+C".action.spawn = ["niri" "msg" "action" "reload-config"];
          "Mod+Shift+Q".action.quit = [];
          "Mod+Shift+Slash".action.show-hotkey-overlay = [];
        };

        # Animations
        animations = {
          slowdown = 1.0;

          workspace-switch.kind.easing = {
            duration-ms = 50;
            curve = "ease-out-quad";
          };

          window-open.kind.easing = {
            duration-ms = 150;
            curve = "ease-out-expo";
          };

          window-close.kind.easing = {
            duration-ms = 150;
            curve = "ease-out-quad";
          };
        };

        # Cursor configuration
        cursor = {
          theme = "Adwaita";
          size = 24;
        };

        # Hotkey overlay settings
        hotkey-overlay = {skip-at-startup = true;};

        # Screenshot configuration
        screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
      };
    };
  }
