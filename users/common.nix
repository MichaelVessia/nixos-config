{
  config,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: {
  # Link scripts to ~/bin (flattened)
  home.file = let
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
      flattened = builtins.concatLists results;
    in
      flattened;
    allScripts = findScripts scriptsDir;
  in
    builtins.listToAttrs (map (scriptPath: {
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
}
