# Hammerspoon configuration for macOS
# Window management: Cmd+Shift+N moves focused window to space N
{
  lib,
  pkgs,
  ...
}: let
  screensend = pkgs.writeShellScriptBin "screensend" ''
    set -e
    ts=$(date +%Y%m%d-%H%M%S)
    tmp="/tmp/screenshot-''${ts}.png"
    ${pkgs.pngpaste}/bin/pngpaste "$tmp"
    if [ ! -s "$tmp" ]; then
      echo "No image in clipboard"
      rm -f "$tmp"
      exit 1
    fi
    ssh claude-casino 'mkdir -p /tmp/screenshots' 2>/dev/null
    scp -q "$tmp" claude-casino:/tmp/screenshots/
    remote_path="/tmp/screenshots/screenshot-''${ts}.png"
    echo "$remote_path"
    echo -n "$remote_path" | pbcopy
    rm "$tmp"
  '';
in
  lib.mkIf pkgs.stdenv.isDarwin {
    home.packages = [screensend];

    home.file.".hammerspoon/init.lua".text = ''
      -- Reload config with Cmd+Shift+R
      hs.hotkey.bind({"cmd", "shift"}, "R", function()
        hs.reload()
      end)
      hs.alert.show("Hammerspoon config loaded")

      -- Cmd+Shift+C: grab clipboard screenshot and send to claude-casino
      hs.hotkey.bind({"cmd", "shift"}, "C", function()
        local task = hs.task.new("${screensend}/bin/screensend", function(exitCode, stdout, stderr)
          if exitCode == 0 then
            hs.alert.show("Screenshot sent")
          else
            hs.alert.show("screensend failed: " .. (stderr or ""))
          end
        end)
        task:start()
      end)

      --[[
      -- Move window to space: BROKEN on macOS Sequoia (15.x)
      -- See: https://github.com/Hammerspoon/hammerspoon/issues/3698
      -- hs.spaces.moveWindowToSpace returns true but doesn't move the window.
      -- Uncomment when fixed.

      local function moveWindowToSpace(spaceNum)
        local win = hs.window.focusedWindow()
        if not win then
          hs.alert.show("No focused window")
          return
        end

        local screen = win:screen()
        local spaces = hs.spaces.spacesForScreen(screen)
        if not spaces or spaceNum > #spaces then
          hs.alert.show("Space " .. spaceNum .. " does not exist")
          return
        end

        local spaceID = spaces[spaceNum]
        hs.spaces.moveWindowToSpace(win:id(), spaceID)
        hs.spaces.gotoSpace(spaceID)
        hs.timer.doAfter(0.1, function() win:focus() end)
      end

      for i = 1, 8 do
        hs.hotkey.bind({"cmd", "shift"}, tostring(i), function()
          moveWindowToSpace(i)
        end)
      end
      --]]
    '';
  }
