{
  programs.nvf.settings.vim = {
    autocomplete.blink-cmp.enable = true;
    utility.snacks-nvim = {
      enable = true;
      setupOpts = {
        gitbrowse.enable = true;
        notifier.enable = true;
        dashboard.enable = false;
      };
    };

    luaConfigRC.dashboard = ''
      require("snacks").config.dashboard = {
        enable = true,
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          {
            pane = 2,
            icon = " ",
            desc = "Browse Repo",
            padding = 1,
            key = "b",
            action = function()
              Snacks.gitbrowse()
            end,
          },
          function()
            local in_git = Snacks.git.get_root() ~= nil
            local cmds = {
              {
                title = "Open Issues",
                cmd = "gh issue list -L 3",
                key = "i",
                action = function()
                  vim.fn.jobstart("gh issue list --web", { detach = true })
                end,
                icon = " ",
                height = 7,
              },
              {
                icon = " ",
                title = "Open PRs",
                cmd = "gh pr list -L 8",
                key = "P",
                action = function()
                  vim.fn.jobstart("gh pr list --web", { detach = true })
                end,
                height = 12,
              },
              {
                icon = " ",
                title = "Git Status",
                cmd = "git --no-pager diff --stat -B -M -C",
                height = 10,
              },
            }
            return vim.tbl_map(function(cmd)
              return vim.tbl_extend("force", {
                pane = 2,
                section = "terminal",
                enabled = in_git,
                padding = 1,
                ttl = 5 * 60,
                indent = 3,
              }, cmd)
            end, cmds)
          end,
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
    '';
  };
}
