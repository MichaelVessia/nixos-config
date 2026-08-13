{pkgs, ...}: let
  neotestWithCleanSubprocessExit = pkgs.vimPlugins.neotest.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace lua/neotest/lib/subprocess.lua \
          --replace-fail 'nio.fn.chanclose(child_chan, "rpc")' \
          'nio.fn.rpcrequest(child_chan, "nvim_command", "qa!")'
      '';
  });
in {
  programs.nvf.settings.vim = {
    extraPlugins = with pkgs.vimPlugins; {
      neotest = {
        package = neotestWithCleanSubprocessExit;
        setup = ''
          require("neotest").setup({})
        '';
      };
      nvim-nio = {
        package = nvim-nio;
      };
    };

    keymaps = [
      {
        key = "<leader>nn";
        mode = "n";
        action = "<cmd>lua require('neotest').run.run()<CR>";
        desc = "Run nearest test";
      }
      {
        key = "<leader>nf";
        mode = "n";
        action = "<cmd>lua require('neotest').run.run(vim.fn.expand('%'))<CR>";
        desc = "Tests in current file";
      }
      {
        key = "<leader>ns";
        mode = "n";
        action = "<cmd>lua require('neotest').summary.toggle()<CR>";
        desc = "Toggle test summary";
      }
    ];
  };
}
