{lib, ...}: {
  programs.nvf.settings.vim = {
    theme = {
      enable = true;
      name = "catppuccin";
      style = "mocha";
      transparent = true;
    };

    luaConfigRC.themeAutoSwitch = lib.mkAfter ''
      -- Follow macOS light/dark appearance: latte when light, mocha when dark.
      -- Linux: no system signal wired up yet, falls through to nvf default.
      local function detect_appearance()
        if vim.fn.has("macunix") == 0 then return nil end
        local out = vim.fn.system({ "defaults", "read", "-g", "AppleInterfaceStyle" })
        return out:match("Dark") and "dark" or "light"
      end

      local function apply_theme()
        local mode = detect_appearance()
        if mode == nil then return end
        vim.o.background = mode
        local ok, catppuccin = pcall(require, "catppuccin")
        if not ok then return end
        catppuccin.setup({
          background = { light = "latte", dark = "mocha" },
          transparent_background = true,
        })
        vim.cmd.colorscheme("catppuccin")
      end

      apply_theme()

      vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
        callback = apply_theme,
      })

      vim.api.nvim_create_user_command("ThemeToggle", function()
        vim.o.background = vim.o.background == "dark" and "light" or "dark"
        vim.cmd.colorscheme("catppuccin")
      end, {})
    '';
  };
}
