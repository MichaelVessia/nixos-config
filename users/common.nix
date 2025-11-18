{
  config,
  pkgs,
  inputs,
  ...
}: {
  # Link scripts to ~/bin (flattened)
  home.file = let
    scriptsDir = ../scripts;
    scriptFiles = [
      "file-management/mkcd"
      "file-management/mksh"
      "file-management/scratch"
      "file-management/tempd"
      "nixos/clean-nix-history"
      "nixos/reload"
      "process-management/pidkill"
      "process-management/portkill"
    ];
  in
    builtins.listToAttrs (map (scriptPath: {
        name = "bin/${builtins.baseNameOf scriptPath}";
        value = {
          source = scriptsDir + "/${scriptPath}";
          executable = true;
        };
      })
      scriptFiles);

  # Add ~/bin to PATH
  home.sessionPath = ["$HOME/bin"];

  home.stateVersion = "25.05";
}
