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
  # - custom_model_pricing: teach agentsview the per-million-token cost of a
  #   model it doesn't know, so cost analytics aren't blank
  #   (https://til.simonwillison.net/llms/agentsview-custom-model-price).
  #   It's a TOML table, so it must come after every top-level key; we strip
  #   then re-append it last via awk (sed line-delete only handles pi_dirs).
  config = {
    home.activation.agentsviewConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
            conf="$HOME/.agentsview/config.toml"
            install -d "$HOME/.agentsview"
            touch "$conf"

            # drop the lines/sections we manage, preserving everything else
            ${pkgs.gnused}/bin/sed -i '/^pi_dirs/d' "$conf"
            tmp="$(mktemp)"
            ${pkgs.gawk}/bin/awk '
              /^\[custom_model_pricing\."claude-fable-5"\]/ { skip=1; next }
              skip==1 && /^\[/ { skip=0 }
              skip==1 { next }
              { print }
            ' "$conf" > "$tmp" && mv "$tmp" "$conf"

            # top-level keys first...
            printf 'pi_dirs = ["%s", "%s"]\n' \
              "$HOME/.pi/agent/sessions" "$HOME/.omp/agent/sessions" >> "$conf"

            # ...then TOML tables
            cat >> "$conf" <<'EOF'

      [custom_model_pricing."claude-fable-5"]
      input = 10.0
      output = 50.0
      cache_creation = 12.50
      cache_read = 1
      EOF
    '';
  };
}
