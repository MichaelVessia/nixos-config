{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nvf.homeManagerModules.default
    ./picker.nix
    ./snacks.nix
  ];

  programs.nvf = {
    enable = true;
    settings.vim = {
      vimAlias = true;
    };
  };
}
