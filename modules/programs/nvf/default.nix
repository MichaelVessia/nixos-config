{inputs, ...}: {
  imports = [
    inputs.nvf.homeManagerModules.default
    ./binds.nix
    ./git.nix
    ./languages.nix
    ./lua.nix
    ./lsp.nix
    ./options.nix
    ./picker.nix
    ./plugins.nix
    ./statusline.nix
    ./terminal.nix
    ./theme.nix
    ./ui.nix
    ./utility.nix
    ./vim.nix
  ];

  programs.nvf.enable = true;
}
