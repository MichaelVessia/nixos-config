{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "rootly-cli";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "rootlyhq";
    repo = "rootly-cli";
    rev = "v${version}";
    hash = "sha256-UDPMv02aGoupZy0XY2ROfig5wTFf6qpMAg+uUUyu38c=";
  };

  vendorHash = "sha256-BE7i3A53JlzIEoH457nJKB0f/Sd3pct9Ck/cuNREUVA=";

  subPackages = ["cmd/rootly"];

  doCheck = false;

  meta = {
    description = "CLI for Rootly incident management";
    homepage = "https://github.com/rootlyhq/rootly-cli";
    license = lib.licenses.mit;
    mainProgram = "rootly";
  };
}
