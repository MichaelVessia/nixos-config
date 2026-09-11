{config, ...}: let
  ompDir = "${config.home.homeDirectory}/nixos-config/modules/programs/agents/omp";
in {
  # Keep OMP's mutable configuration in the repository. OMP 17.4+ resolves
  # config symlinks before atomic writes, so /settings and `omp config set`
  # update the tracked target without replacing this link.
  home.file.".omp/agent/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${ompDir}/config.yml";
}
