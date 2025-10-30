{pkgs-unstable, ...}: {
  programs.nvf.settings = {
    vim = {
      lazy.plugins."grug-far.nvim" = {
        package = pkgs-unstable.vimPlugins.grug-far-nvim;
        setupModule = "grug-far";
        cmd = ["GrugFar"];
      };

      keymaps = [
        {
          key = "<leader>sr";
          mode = "n";
          action = "<cmd>GrugFar<CR>";
          desc = "GrugFar toggle";
        }
      ];
    };
  };
}
