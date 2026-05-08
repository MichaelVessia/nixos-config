{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "pup";
  version = "0.58.4";

  src = fetchFromGitHub {
    owner = "datadog-labs";
    repo = "pup";
    rev = "v${version}";
    hash = "sha256-nWfFLoyLVUuFvsm5IZVCoIzk+PJIgwfUnZyE5KnzcPA=";
  };

  cargoHash = "sha256-xwayUDimovu/nEDenD18nYoHxWCr5unCM3AMoqfUVNQ=";

  # Tests rely on runtime environment and network-adjacent behavior
  doCheck = false;

  meta = {
    description = "CLI wrapper for Datadog APIs";
    homepage = "https://github.com/datadog-labs/pup";
    license = lib.licenses.asl20;
    mainProgram = "pup";
  };
}
