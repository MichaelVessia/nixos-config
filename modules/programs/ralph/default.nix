{
  lib,
  stdenvNoCC,
  makeWrapper,
  substituteAll,
  jq,
  git,
}:
stdenvNoCC.mkDerivation {
  pname = "ralph";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install scripts (these get copied to target repos)
    mkdir -p $out/share/ralph/scripts
    cp scripts/ralph.sh $out/share/ralph/scripts/
    cp scripts/ci-check.sh $out/share/ralph/scripts/
    cp scripts/prd-status.sh $out/share/ralph/scripts/
    cp scripts/prd-update.sh $out/share/ralph/scripts/
    cp scripts/stream-filter.sh $out/share/ralph/scripts/

    # Install templates
    mkdir -p $out/share/ralph/templates
    cp templates/RALPH_PROMPT.md $out/share/ralph/templates/
    cp templates/HOW_TO_RALPH.md $out/share/ralph/templates/
    cp templates/prd.json $out/share/ralph/templates/
    cp templates/progress.txt $out/share/ralph/templates/

    # Create ralph-init with paths substituted
    mkdir -p $out/bin
    substitute scripts/ralph-init.sh $out/bin/ralph-init \
      --replace-fail "@scriptsDir@" "$out/share/ralph/scripts" \
      --replace-fail "@templatesDir@" "$out/share/ralph/templates"
    chmod +x $out/bin/ralph-init

    # Wrap ralph-init with runtime dependencies
    wrapProgram $out/bin/ralph-init \
      --prefix PATH : ${lib.makeBinPath [jq git]}

    runHook postInstall
  '';

  meta = {
    description = "Ralph autonomous coding agent scaffolding tool";
    mainProgram = "ralph-init";
  };
}
