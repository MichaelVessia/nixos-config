# stack - squash-safe stacked PR/MR repair CLI for GitHub and GitLab
# https://github.com/kitlangton/stack
#
# Published as an npm package (@kitlangton/stack) built with bun; no
# package-lock.json upstream, so buildNpmPackage can't pin it. Instead wrap
# npx with a pinned version: first run downloads into the npx cache, after
# that it's instant.
{pkgs, ...}: let
  version = "0.2.0";
  stack = pkgs.writeShellScriptBin "stack" ''
    exec ${pkgs.nodejs}/bin/npx -y @kitlangton/stack@${version} "$@"
  '';
in {
  home.packages = [stack];
}
