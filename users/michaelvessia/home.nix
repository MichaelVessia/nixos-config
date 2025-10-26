{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ../../modules/programs
  ];

  home.username = "michaelvessia";
  home.homeDirectory = "/home/michaelvessia";

  # Link scripts to ~/bin
  home.file."bin" = {
    source = ../../scripts;
    recursive = true;
    executable = true;
  };

  # Add ~/bin to PATH
  home.sessionPath = ["$HOME/bin"];

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # programs.claude-code = {
  #   enable = true;
  #   package = inputs.claude-code.packages.${pkgs.system}.default;
  # };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
