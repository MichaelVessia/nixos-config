#!/usr/bin/env bash
# Format all Nix files in the project using alejandra
nix run nixpkgs#alejandra -- .
