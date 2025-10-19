{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nvf.homeManagerModules.default
    ./picker.nix
    ./snacks.nix
    ./options.nix
    ./languages.nix
  ];

  programs.nvf = {
    enable = true;
  };
}
