{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "pup";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "DataDog";
    repo = "pup";
    rev = version;
    hash = "sha256-VzFU55VKlocvX5TBI04hOLrEeYNb5Wc8Br/ykaAUntA=";
  };

  vendorHash = "sha256-Va6CwpykKeqFVqLxFeWkUbNprK5187STGqCFAyGs3CM=";

  # Tests require filesystem and keychain access unavailable in the Nix sandbox
  doCheck = false;

  meta = {
    description = "CLI wrapper for Datadog APIs";
    homepage = "https://github.com/DataDog/pup";
    license = lib.licenses.asl20;
    mainProgram = "pup";
  };
}
