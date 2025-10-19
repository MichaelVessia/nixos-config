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
  ];

  programs.nvf = {
    enable = true;
  };
}
