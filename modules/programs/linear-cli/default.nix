{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "linear-cli";
  version = "0.3.22";

  src = fetchFromGitHub {
    owner = "Finesssee";
    repo = "linear-cli";
    rev = "104c71c2f16822894685697e779795b0b8c2996e";
    hash = "sha256-dA8Bru8azI8uGeBd0YCEuqBBYZ+xt+2ErFVwfNQJ40A=";
  };

  cargoHash = "sha256-etdPb1ikn1bhVJ9mL2Kfl9R2R/dFS36Jb8POHhJB+uo=";

  doCheck = false;

  meta = {
    description = "CLI for Linear.app issues, projects, cycles, and more";
    homepage = "https://github.com/Finesssee/linear-cli";
    license = lib.licenses.mit;
    mainProgram = "linear-cli";
  };
}
