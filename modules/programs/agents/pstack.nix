{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  source = pkgs.runCommand "t3-pstack-source" {nativeBuildInputs = [pkgs.patch];} ''
    cp -R ${inputs.t3-pstack}/. "$out"
    chmod -R u+w "$out"
    cd "$out"
    patch -p1 < ${./pstack/inherit-panels.patch}
  '';
  # A stable path lets each CLI keep its marketplace registration across updates.
  sourcePath = "${config.home.homeDirectory}/.local/share/t3-pstack/source";
  installer = pkgs.writeShellApplication {
    name = "t3-pstack";
    runtimeInputs = [pkgs.nodejs pkgs.git];
    text = ''
      exec node ${source}/tools/install.mjs "$@" --source ${lib.escapeShellArg sourcePath}
    '';
  };
in {
  home.packages = [installer];
  home.file.".local/share/t3-pstack/source".source = source;
  home.file.".config/t3-pstack/models.md".source = ./shared/pstack-models.md;

  # Run after writable CLI settings and the source/model links exist. The
  # upstream installer discovers additional provider homes from T3 settings.
  home.activation.pstackInstall = lib.hm.dag.entryAfter ["linkGeneration" "codexConfig" "claudeConfig"] ''
    export PATH="${config.home.profileDirectory}/bin:$PATH"
    $DRY_RUN_CMD ${installer}/bin/t3-pstack install
  '';
}
