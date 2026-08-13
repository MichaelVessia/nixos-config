{
  lib,
  pkgs,
  ...
}: let
  py = pkgs.python313Packages;

  sulguk = py.buildPythonPackage rec {
    pname = "sulguk";
    version = "0.11.1";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-LYesSClo6vP+ZivP9k4flO2E/B7bBahyt+Q0PTbkhv4=";
    };

    build-system = with py; [
      setuptools
      wheel
    ];

    propagatedBuildInputs = with py; [
      html5lib
      lxml
    ];

    doCheck = false;

    meta = with lib; {
      description = "Convert HTML to Telegram entities";
      homepage = "https://github.com/tishka17/sulguk";
      license = licenses.asl20;
    };
  };

  takopi = py.buildPythonApplication rec {
    pname = "takopi";
    version = "0.22.1";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-Qv1HcEY6VF3q3T8wf+T+uIR4eI5nY3/o1u6Lw/FmP5o=";
    };

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace-fail 'requires = ["uv_build>=0.9.18,<0.10.0"]' 'requires = ["uv_build>=0.9.7,<0.10.0"]' \
        --replace-fail 'requires-python = ">=3.14"' 'requires-python = ">=3.13"'
    '';

    nativeBuildInputs = with py; [
      py."uv-build"
      pythonRelaxDepsHook
    ];

    # nixpkgs versions are slightly behind takopi's declared minimums.
    pythonRelaxDeps = true;

    propagatedBuildInputs = [
      py.anyio
      py.httpx
      py."markdown-it-py"
      py.msgspec
      py.openai
      py.pydantic
      py."pydantic-settings"
      py.questionary
      py.rich
      py.structlog
      sulguk
      py."tomli-w"
      py.typer
      py.watchfiles
    ];

    pythonImportsCheck = ["takopi"];
    doCheck = false;

    meta = with lib; {
      description = "Telegram bridge for Codex, Claude Code, and other agent CLIs";
      homepage = "https://github.com/banteg/takopi";
      license = licenses.mit;
      mainProgram = "takopi";
    };
  };
in {
  home.packages = [takopi];
}
