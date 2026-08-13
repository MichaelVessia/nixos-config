{
  lib,
  pkgs,
  ...
}: {
  # agentsview owns ~/.agentsview/config.toml (it writes a generated
  # cursor_secret into it), so we can't declare the whole file. Instead,
  # idempotently manage the lines we care about:
  #
  # - pi_dirs: agentsview has no native omp support, but omp sessions parse
  #   as Pi agent type when their dir is listed in pi_dirs
  #   (kenn-io/agentsview#486). Tilde is not expanded in config values, so
  #   paths must be absolute.
  #
  # The awk cleanup also removes the obsolete custom_model_pricing table
  # previously managed here, while preserving agentsview-owned settings.
  config = {
    home.activation.agentsviewConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      conf="$HOME/.agentsview/config.toml"
      install -d "$HOME/.agentsview"
      touch "$conf"

      # drop the lines/sections we manage, preserving everything else
      ${pkgs.gnused}/bin/sed -i '/^pi_dirs/d' "$conf"
      tmp="$(mktemp)"
      # agentsview may have re-serialized the legacy pricing section,
      # so match any spelling when removing it
      ${pkgs.gawk}/bin/awk '
        /^[[:space:]]*\[custom_model_pricing[].]/ { skip=1; next }
        skip==1 && /^[[:space:]]*\[/ { skip=0 }
        skip==1 { next }
        { print }
      ' "$conf" > "$tmp" && mv "$tmp" "$conf"

      printf 'pi_dirs = ["%s", "%s"]\n' \
        "$HOME/.pi/agent/sessions" "$HOME/.omp/agent/sessions" >> "$conf"
    '';
  };
}
