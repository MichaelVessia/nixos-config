{
  config,
  lib,
  ...
}: let
  scriptsDir = ../scripts;
  # Recursively find all executable files in scripts directory
  findScripts = dir: let
    contents = builtins.readDir dir;
    names = builtins.attrNames contents;
    results =
      map (
        name: let
          path = dir + "/${name}";
          type = contents.${name};
        in
          if type == "directory"
          then findScripts path
          else if type == "regular" && builtins.substring 0 1 name != "."
          then [path]
          else []
      )
      names;
  in
    builtins.concatLists results;
  scriptGroups = config.scripts.groups;
  allScripts =
    if scriptGroups == null
    then findScripts scriptsDir
    else lib.concatMap (group: findScripts (scriptsDir + "/${group}")) scriptGroups;
in {
  options.scripts.groups = lib.mkOption {
    type = lib.types.nullOr (lib.types.listOf lib.types.str);
    default = null;
    description = "Subdirectories of scripts/ to link into ~/bin. Null links every script.";
  };

  config = {
    # Link scripts to ~/bin (flattened)
    home.file = builtins.listToAttrs (map (scriptPath: {
        name = "bin/${builtins.baseNameOf scriptPath}";
        value = {
          source = scriptPath;
          executable = true;
        };
      })
      allScripts);

    # Add ~/bin to PATH
    home.sessionPath = ["$HOME/bin"];

    home.stateVersion = "25.05";
  };
}
