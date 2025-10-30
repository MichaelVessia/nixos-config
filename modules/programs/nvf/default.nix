{inputs, ...}: {
  imports = [
    inputs.nvf.homeManagerModules.default
    ./binds.nix
    ./dashboard.nix
    ./git.nix
    ./languages.nix
    ./lua.nix
    ./lsp.nix
    ./options.nix
    ./picker.nix
    ./statusline.nix
    ./terminal.nix
    ./theme.nix
    ./ui.nix
    ./utility.nix
    ./vim.nix
    ./find-and-replace.nix
  ];

  programs.nvf.enable = true;
}
