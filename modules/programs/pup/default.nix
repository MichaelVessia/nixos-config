{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "pup";
  version = "0.22.4";

  src = fetchFromGitHub {
    owner = "datadog-labs";
    repo = "pup";
    rev = "v${version}";
    hash = "sha256-nDjfwM8+REyaStrjvxz1pW/8wMW/eW5e7UJKW4mBvCc=";
  };

  cargoHash = "sha256-cmiJL98ygIZXgvCr5derxg7fy+NXTiKKsmerXM1mJQ0=";

  # Tests rely on runtime environment and network-adjacent behavior
  doCheck = false;

  meta = {
    description = "CLI wrapper for Datadog APIs";
    homepage = "https://github.com/datadog-labs/pup";
    license = lib.licenses.asl20;
    mainProgram = "pup";
  };
}
