{
  inputs,
  pkgs,
  ...
}: {
  config.home.packages = [inputs.llm-agents.packages.${pkgs.system}.plannotator];
}
