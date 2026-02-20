# Hammerspoon configuration for macOS
# Window management: Cmd+Shift+N moves focused window to space N
{
  lib,
  pkgs,
  ...
}:
lib.mkIf pkgs.stdenv.isDarwin {
  home.file.".hammerspoon/init.lua".text = ''
    -- Reload config with Cmd+Shift+R
    hs.hotkey.bind({"cmd", "shift"}, "R", function()
      hs.reload()
    end)
    hs.alert.show("Hammerspoon config loaded")

    -- Cmd+Shift+C: grab clipboard screenshot and send to claude-casino
    hs.hotkey.bind({"cmd", "shift"}, "C", function()
      local task = hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
        if exitCode == 0 then
          hs.alert.show("Screenshot sent")
        else
          hs.alert.show("screensend failed: " .. (stderr or ""))
        end
      end, {"-l", "-c", "screensend"})
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
