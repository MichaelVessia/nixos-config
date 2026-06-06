{
  lib,
  pkgs,
  ...
}: {
  # agentsview owns ~/.agentsview/config.toml (it writes a generated
  # cursor_secret into it), so we can't declare the whole file. Instead,
  # idempotently manage the pi_dirs line: agentsview has no native omp
  # support, but omp sessions parse as Pi agent type when their dir is
  # listed in pi_dirs (kenn-io/agentsview#486). Tilde is not expanded in
  # config values, so paths must be absolute.
  config = {
    home.activation.agentsviewConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      conf="$HOME/.agentsview/config.toml"
      install -d "$HOME/.agentsview"
      touch "$conf"
      ${pkgs.gnused}/bin/sed -i '/^pi_dirs/d' "$conf"
      printf 'pi_dirs = ["%s", "%s"]\n' \
        "$HOME/.pi/agent/sessions" "$HOME/.omp/agent/sessions" >> "$conf"
    '';
  };
}
