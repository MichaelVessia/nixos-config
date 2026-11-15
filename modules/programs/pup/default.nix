{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  zstd,
  stdenv,
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

  # zstd-sys links the system libzstd through pkg-config.
  # Darwin uses the system TLS framework; Linux links openssl-sys.
  nativeBuildInputs = [pkg-config];
  buildInputs = [zstd] ++ lib.optionals stdenv.isLinux [openssl];

  # Tests rely on runtime environment and network-adjacent behavior
  doCheck = false;

  meta = {
    description = "CLI wrapper for Datadog APIs";
    homepage = "https://github.com/datadog-labs/pup";
    license = lib.licenses.asl20;
    mainProgram = "pup";
  };
}
