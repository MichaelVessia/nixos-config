{inputs, ...}: {
  imports = [
    inputs.nvf.homeManagerModules.default
    ./picker.nix
    ./oil.nix
    ./vim.nix
    ./languages.nix
    ./plugins.nix
    ./git.nix
    ./terminal.nix
    ./llm.nix
  ];

  programs.nvf.enable = true;
}
