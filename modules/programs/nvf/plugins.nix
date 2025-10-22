{
  programs.nvf.settings.vim = {
    autocomplete.blink-cmp.enable = true;
    utility.snacks-nvim = {
      enable = true;
      setupOpts = {
        gitbrowse.enable = true;
        notifier.enable = true;
        dashboard.enable = false;
        explorer.enable = true;
      };
    };

    luaConfigRC.dashboard = ''
      require("snacks").config.dashboard = {
        enable = true,
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          {
            icon = " ",
            desc = "Browse Repo",
            padding = 1,
            key = "b",
            action = function()
              Snacks.gitbrowse()
            end,
          },
          {
            icon = " ",
            desc = "Browse Issues",
            padding = 1,
            key = "i",
            action = function()
              vim.fn.jobstart("gh issue list --web", { detach = true })
            end,
          },
          {
            icon = " ",
            desc = "Browse PRs",
            padding = 1,
            key = "p",
            action = function()
              vim.fn.jobstart("gh pr list --web", { detach = true })
            end,
          },
        },
      }
      vim.api.nvim_create_autocmd("UIEnter", {
        once = true,
        callback = function()
          if vim.fn.argc() == 0 then
            require("snacks.dashboard").open()
          end
        end,
      })

      vim.keymap.set("n", "<leader>d", function()
        require("snacks.dashboard").open()
      end, { desc = "Open Dashboard" })

      vim.keymap.set("n", "<leader>e", function()
        require("snacks").explorer()
      end, { desc = "Explorer" })
    '';
  };
}
